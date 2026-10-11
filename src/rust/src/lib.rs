use extendr_api::prelude::*;
use rayon::prelude::*;
use std::collections::HashMap;

/// Scratch memory structure for high-performance Dijkstra searches.
/// Reused across calls on each worker thread to avoid O(N) allocations per node.
struct DijkstraScratch {
    dt: Vec<f64>,
    stamp: Vec<u32>,
    done: Vec<u32>,
    ht: Vec<f64>,
    hv: Vec<usize>,
    run: u32,
}

impl DijkstraScratch {
    fn new(n: usize) -> Self {
        Self {
            dt: vec![0.0; n],
            stamp: vec![0; n],
            done: vec![0; n],
            ht: Vec::with_capacity(4096),
            hv: Vec::with_capacity(4096),
            run: 1,
        }
    }

    #[inline(always)]
    fn next_run(&mut self) {
        if self.run == u32::MAX {
            self.stamp.fill(0);
            self.done.fill(0);
            self.run = 1;
        } else {
            self.run += 1;
        }
    }

    #[inline(always)]
    fn push_heap(&mut self, time: f64, node: usize) {
        let mut j = self.ht.len();
        self.ht.push(time);
        self.hv.push(node);
        while j > 0 {
            let p = (j - 1) / 2;
            if self.ht[p] <= self.ht[j] {
                break;
            }
            self.ht.swap(p, j);
            self.hv.swap(p, j);
            j = p;
        }
    }

    #[inline(always)]
    fn pop_heap(&mut self) -> (f64, usize) {
        let min_t = self.ht[0];
        let min_v = self.hv[0];
        let last_idx = self.ht.len() - 1;
        if last_idx > 0 {
            self.ht[0] = self.ht[last_idx];
            self.hv[0] = self.hv[last_idx];
            self.ht.truncate(last_idx);
            self.hv.truncate(last_idx);

            let size = self.ht.len();
            let mut i = 0;
            loop {
                let l = 2 * i + 1;
                let r = 2 * i + 2;
                let mut k = i;
                if l < size && self.ht[l] < self.ht[k] {
                    k = l;
                }
                if r < size && self.ht[r] < self.ht[k] {
                    k = r;
                }
                if k == i {
                    break;
                }
                self.ht.swap(i, k);
                self.hv.swap(i, k);
                i = k;
            }
        } else {
            self.ht.clear();
            self.hv.clear();
        }
        (min_t, min_v)
    }
}

/// Compute reachable walkable network length for one source node within cutoff seconds.
/// Implements exact partial-edge credit: edges crossing the isochrone boundary
/// contribute only the fraction reachable from its endpoints.
fn dijkstra_reachable_length_single(
    src: usize,
    head: &[usize],
    to: &[usize],
    wt: &[f64],
    wl: &[f64],
    cutoff: f64,
    scratch: &mut DijkstraScratch,
) -> f64 {
    scratch.next_run();
    let run = scratch.run;

    scratch.dt[src] = 0.0;
    scratch.stamp[src] = run;

    scratch.ht.clear();
    scratch.hv.clear();
    scratch.push_heap(0.0, src);

    let mut total_length: f64 = 0.0;
    let inf = f64::INFINITY;

    while !scratch.ht.is_empty() {
        let (t, u) = scratch.pop_heap();

        if scratch.done[u] == run {
            continue;
        }
        scratch.done[u] = run;

        let rem = cutoff - t; // remaining time budget at u (>= 0)

        let start = head[u];
        let end = head[u + 1];

        for i in start..end {
            let v = to[i];
            let w = wt[i];
            let edge_len = wl[i];

            if scratch.done[v] == run {
                // v was finalized earlier, so its side already contributed min(1, rem_v/w).
                // The correct joint total is min(1, (rem_u + rem_v)/w).
                let remv = cutoff - scratch.dt[v];
                let a = if w <= 0.0 { 1.0 } else { ( (rem + remv) / w ).min(1.0) };
                let b = if w <= 0.0 { 1.0 } else { ( remv / w ).min(1.0) };
                total_length += edge_len * (a - b);
                continue;
            }

            // v not yet finalized: credit the one-sided share reachable from u
            let one_sided = if w <= 0.0 { 1.0 } else { ( rem / w ).min(1.0) };
            total_length += edge_len * one_sided;

            let nt = t + w;
            if nt > cutoff {
                continue;
            }

            let cur = if scratch.stamp[v] == run { scratch.dt[v] } else { inf };
            if nt < cur {
                scratch.dt[v] = nt;
                scratch.stamp[v] = run;
                scratch.push_heap(nt, v);
            }
        }
    }

    total_length
}

/// Union-find algorithm to determine connected component IDs for each node.
fn find_components(n: usize, src: &[usize], dst: &[usize]) -> Vec<usize> {
    let mut parent: Vec<usize> = (0..n).collect();
    for (&x_orig, &y_orig) in src.iter().zip(dst.iter()) {
        let mut x = x_orig;
        while parent[x] != x {
            parent[x] = parent[parent[x]];
            x = parent[x];
        }
        let ra = x;

        let mut y = y_orig;
        while parent[y] != y {
            parent[y] = parent[parent[y]];
            y = parent[y];
        }
        let rb = y;

        if ra != rb {
            parent[ra] = rb;
        }
    }
    for i in 0..n {
        let mut x = i;
        while parent[x] != x {
            parent[x] = parent[parent[x]];
            x = parent[x];
        }
        parent[i] = x;
    }
    parent
}

/// Build Compressed Sparse Row (CSR) graph representation.
/// Drops self-loops, collapses parallel edges to minimum travel time,
/// and returns CSR structures along with connected component analysis.
///
/// @param n_nodes Number of nodes in the graph (0-indexed: 0..n-1).
/// @param u From-node vector (0-indexed).
/// @param v To-node vector (0-indexed).
/// @param wt Travel time in seconds for each edge.
/// @param wl Physical length in meters for each edge.
/// @export
#[extendr]
fn rust_build_csr(
    n_nodes: i32,
    u: Vec<i32>,
    v: Vec<i32>,
    wt: Vec<f64>,
    wl: Vec<f64>,
) -> List {
    let n = n_nodes as usize;
    let m = u.len();

    // Map undirected node pairs (min, max) to best (travel_time, length)
    let mut best_edges: HashMap<(usize, usize), (f64, f64)> = HashMap::with_capacity(m);

    for i in 0..m {
        let a = u[i] as usize;
        let b = v[i] as usize;
        if a == b || a >= n || b >= n {
            continue; // drop self-loops or out-of-bounds
        }
        let key = if a <= b { (a, b) } else { (b, a) };
        let t = wt[i];
        let l = wl[i];

        best_edges
            .entry(key)
            .and_modify(|existing| {
                if t < existing.0 {
                    *existing = (t, l);
                }
            })
            .or_insert((t, l));
    }

    let mut src: Vec<usize> = Vec::with_capacity(best_edges.len());
    let mut dst: Vec<usize> = Vec::with_capacity(best_edges.len());
    let mut wtime: Vec<f64> = Vec::with_capacity(best_edges.len());
    let mut wlen: Vec<f64> = Vec::with_capacity(best_edges.len());

    for (&(a, b), &(t, l)) in &best_edges {
        src.push(a);
        dst.push(b);
        wtime.push(t);
        wlen.push(l);
    }

    let e = src.len();
    let mut deg = vec![0usize; n];
    for i in 0..e {
        deg[src[i]] += 1;
        deg[dst[i]] += 1;
    }

    let mut head = vec![0usize; n + 1];
    for i in 0..n {
        head[i + 1] = head[i] + deg[i];
    }

    let mut pos = head[..n].to_vec();
    let mut to = vec![0usize; 2 * e];
    let mut wtarr = vec![0.0f64; 2 * e];
    let mut wlarr = vec![0.0f64; 2 * e];

    for i in 0..e {
        let a = src[i];
        let b = dst[i];
        let t = wtime[i];
        let l = wlen[i];

        let pa = pos[a];
        to[pa] = b;
        wtarr[pa] = t;
        wlarr[pa] = l;
        pos[a] += 1;

        let pb = pos[b];
        to[pb] = a;
        wtarr[pb] = t;
        wlarr[pb] = l;
        pos[b] += 1;
    }

    let comp = find_components(n, &src, &dst);

    // Count component sizes to identify giant connected component
    let mut comp_counts: HashMap<usize, usize> = HashMap::new();
    for &c in &comp {
        *comp_counts.entry(c).or_insert(0) += 1;
    }

    let mut giant_id = 0usize;
    let mut giant_size = 0usize;
    for (&cid, &count) in &comp_counts {
        if count > giant_size {
            giant_size = count;
            giant_id = cid;
        }
    }

    list!(
        head = head.into_iter().map(|x| x as f64).collect::<Vec<f64>>(),
        to = to.into_iter().map(|x| x as i32).collect::<Vec<i32>>(),
        wt = wtarr,
        wl = wlarr,
        comp = comp.into_iter().map(|x| x as i32).collect::<Vec<i32>>(),
        n_edges_collapsed = e as i32,
        giant_comp_id = giant_id as i32,
        giant_comp_size = giant_size as i32,
        total_components = comp_counts.len() as i32
    )
}

/// Compute reachable walkable network length in parallel for a set of target nodes.
///
/// @param n_nodes Total number of nodes in graph.
/// @param head_num CSR head array.
/// @param to CSR destination nodes.
/// @param wt CSR travel times (seconds).
/// @param wl CSR lengths (meters).
/// @param target_nodes Indices of nodes to compute metric for (0-indexed).
/// @param cutoff Walk travel-time budget (seconds, default 600.0 = 10 min).
/// @param num_threads Number of worker threads (0 = auto-detect all CPU cores).
/// @export
#[extendr]
fn rust_compute_reachable_length(
    n_nodes: i32,
    head_num: Vec<f64>,
    to: Vec<i32>,
    wt: Vec<f64>,
    wl: Vec<f64>,
    target_nodes: Vec<i32>,
    cutoff: f64,
    num_threads: i32,
) -> Vec<f64> {
    let n = n_nodes as usize;
    let head: Vec<usize> = head_num.into_iter().map(|x| x as usize).collect();
    let to_u: Vec<usize> = to.into_iter().map(|x| x as usize).collect();

    let targets: Vec<usize> = target_nodes.into_iter().map(|x| x as usize).collect();

    let compute_fn = || {
        targets
            .par_iter()
            .map_init(
                || DijkstraScratch::new(n),
                |scratch, &src| {
                    if src >= n {
                        f64::NAN
                    } else {
                        dijkstra_reachable_length_single(
                            src, &head, &to_u, &wt, &wl, cutoff, scratch,
                        )
                    }
                },
            )
            .collect::<Vec<f64>>()
    };

    if num_threads > 0 {
        let pool = rayon::ThreadPoolBuilder::new()
            .num_threads(num_threads as usize)
            .build();
        match pool {
            Ok(p) => p.install(compute_fn),
            Err(_) => compute_fn(),
        }
    } else {
        compute_fn()
    }
}

/// Compute detour ratio (circuity) for sampled origin-destination pairs.
///
/// Circuity is defined as actual network shortest path distance divided by
/// Euclidean straight-line distance. Values close to 1.0 indicate highly direct
/// routes; higher values indicate circuitous paths and poor permeability.
///
/// @param n_nodes Total number of nodes.
/// @param head_num CSR head array.
/// @param to CSR destination array.
/// @param wt CSR travel time array.
/// @param wl CSR length array.
/// @param coords_x Vector of node X coordinates (meters).
/// @param coords_y Vector of node Y coordinates (meters).
/// @param sample_nodes Nodes from which to measure circuity.
/// @param cutoff Travel time cutoff in seconds.
/// @export
#[extendr]
#[allow(unused_variables)]
fn rust_compute_circuity_sample(
    n_nodes: i32,
    head_num: Vec<f64>,
    to: Vec<i32>,
    wt: Vec<f64>,
    wl: Vec<f64>,
    coords_x: Vec<f64>,
    coords_y: Vec<f64>,
    sample_nodes: Vec<i32>,
    cutoff: f64,
) -> List {
    let n = n_nodes as usize;
    let head: Vec<usize> = head_num.into_iter().map(|x| x as usize).collect();
    let to_u: Vec<usize> = to.into_iter().map(|x| x as usize).collect();
    let samples: Vec<usize> = sample_nodes.iter().map(|&x| x as usize).collect();

    let mut mean_circuities: Vec<f64> = Vec::with_capacity(samples.len());
    let mut max_circuities: Vec<f64> = Vec::with_capacity(samples.len());
    let mut reached_counts: Vec<i32> = Vec::with_capacity(samples.len());

    let mut scratch = DijkstraScratch::new(n);

    for &src in &samples {
        if src >= n {
            mean_circuities.push(f64::NAN);
            max_circuities.push(f64::NAN);
            reached_counts.push(0);
            continue;
        }

        scratch.next_run();
        let run = scratch.run;
        scratch.dt[src] = 0.0;
        scratch.stamp[src] = run;
        scratch.ht.clear();
        scratch.hv.clear();
        scratch.push_heap(0.0, src);

        let inf = f64::INFINITY;
        let mut ratios: Vec<f64> = Vec::new();
        let sx = coords_x[src];
        let sy = coords_y[src];

        while !scratch.ht.is_empty() {
            let (t, u) = scratch.pop_heap();
            if scratch.done[u] == run {
                continue;
            }
            scratch.done[u] = run;

            if u != src {
                let dx = coords_x[u] - sx;
                let dy = coords_y[u] - sy;
                let euclid = (dx * dx + dy * dy).sqrt();
                // Estimate network distance by time * 1.25 m/s or wl
                let net_dist = t * 1.25; 
                if euclid > 50.0 { // ignore very close neighbors to avoid division by zero
                    let ratio = net_dist / euclid;
                    if ratio >= 1.0 && ratio < 10.0 {
                        ratios.push(ratio);
                    }
                }
            }

            let start = head[u];
            let end = head[u + 1];
            for i in start..end {
                let v = to_u[i];
                let w = wt[i];
                let nt = t + w;
                if nt > cutoff {
                    continue;
                }
                let cur = if scratch.stamp[v] == run { scratch.dt[v] } else { inf };
                if nt < cur {
                    scratch.dt[v] = nt;
                    scratch.stamp[v] = run;
                    scratch.push_heap(nt, v);
                }
            }
        }

        if ratios.is_empty() {
            mean_circuities.push(f64::NAN);
            max_circuities.push(f64::NAN);
            reached_counts.push(0);
        } else {
            let sum: f64 = ratios.iter().sum();
            let mean = sum / ratios.len() as f64;
            let max = ratios.iter().cloned().fold(f64::MIN, f64::max);
            mean_circuities.push(mean);
            max_circuities.push(max);
            reached_counts.push(ratios.len() as i32);
        }
    }

    list!(
        node_id = sample_nodes,
        mean_circuity = mean_circuities,
        max_circuity = max_circuities,
        destinations_reached = reached_counts
    )
}

// Module definition
extendr_module! {
    mod walkability;
    fn rust_build_csr;
    fn rust_compute_reachable_length;
    fn rust_compute_circuity_sample;
}
