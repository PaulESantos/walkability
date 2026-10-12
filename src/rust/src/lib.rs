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

/// Compute shortest path between source and target nodes using Dijkstra.
///
/// @param n_nodes Total number of nodes.
/// @param head_num CSR head array.
/// @param to CSR destination array.
/// @param wt CSR travel time array (seconds).
/// @param wl CSR length array (meters).
/// @param src_node Origin node (0-indexed).
/// @param dst_node Destination node (0-indexed).
/// @export
#[extendr]
fn rust_shortest_path(
    n_nodes: i32,
    head_num: Vec<f64>,
    to: Vec<i32>,
    wt: Vec<f64>,
    wl: Vec<f64>,
    src_node: i32,
    dst_node: i32,
) -> List {
    let n = n_nodes as usize;
    let head: Vec<usize> = head_num.into_iter().map(|x| x as usize).collect();
    let to_u: Vec<usize> = to.into_iter().map(|x| x as usize).collect();

    let src = src_node as usize;
    let dst = dst_node as usize;

    if src >= n || dst >= n {
        return list!(
            found = false,
            node_path = Vec::<i32>::new(),
            edge_indices = Vec::<i32>::new(),
            total_time_s = f64::NAN,
            total_length_m = f64::NAN
        );
    }

    if src == dst {
        return list!(
            found = true,
            node_path = vec![src_node],
            edge_indices = Vec::<i32>::new(),
            total_time_s = 0.0,
            total_length_m = 0.0
        );
    }

    let mut dist = vec![f64::INFINITY; n];
    let mut dist_len = vec![0.0f64; n];
    let mut prev_node = vec![usize::MAX; n];
    let mut prev_edge = vec![usize::MAX; n];
    let mut done = vec![false; n];

    let mut ht: Vec<f64> = Vec::with_capacity(1024);
    let mut hv: Vec<usize> = Vec::with_capacity(1024);

    let push_heap = |ht: &mut Vec<f64>, hv: &mut Vec<usize>, time: f64, node: usize| {
        let mut j = ht.len();
        ht.push(time);
        hv.push(node);
        while j > 0 {
            let p = (j - 1) / 2;
            if ht[p] <= ht[j] {
                break;
            }
            ht.swap(p, j);
            hv.swap(p, j);
            j = p;
        }
    };

    let pop_heap = |ht: &mut Vec<f64>, hv: &mut Vec<usize>| -> (f64, usize) {
        let min_t = ht[0];
        let min_v = hv[0];
        let last_idx = ht.len() - 1;
        if last_idx > 0 {
            ht[0] = ht[last_idx];
            hv[0] = hv[last_idx];
            ht.truncate(last_idx);
            hv.truncate(last_idx);

            let size = ht.len();
            let mut i = 0;
            loop {
                let l = 2 * i + 1;
                let r = 2 * i + 2;
                let mut k = i;
                if l < size && ht[l] < ht[k] {
                    k = l;
                }
                if r < size && ht[r] < ht[k] {
                    k = r;
                }
                if k == i {
                    break;
                }
                ht.swap(i, k);
                hv.swap(i, k);
                i = k;
            }
        } else {
            ht.clear();
            hv.clear();
        }
        (min_t, min_v)
    };

    dist[src] = 0.0;
    push_heap(&mut ht, &mut hv, 0.0, src);

    let mut found = false;

    while !ht.is_empty() {
        let (t, u) = pop_heap(&mut ht, &mut hv);
        if done[u] {
            continue;
        }
        done[u] = true;

        if u == dst {
            found = true;
            break;
        }

        let start = head[u];
        let end = head[u + 1];

        for i in start..end {
            let v = to_u[i];
            let w = wt[i];
            let l = wl[i];

            if done[v] {
                continue;
            }

            let nt = t + w;
            if nt < dist[v] {
                dist[v] = nt;
                dist_len[v] = dist_len[u] + l;
                prev_node[v] = u;
                prev_edge[v] = i;
                push_heap(&mut ht, &mut hv, nt, v);
            }
        }
    }

    if !found {
        return list!(
            found = false,
            node_path = Vec::<i32>::new(),
            edge_indices = Vec::<i32>::new(),
            total_time_s = f64::NAN,
            total_length_m = f64::NAN
        );
    }

    // Trace path from dst back to src
    let mut node_path: Vec<i32> = Vec::new();
    let mut edge_indices: Vec<i32> = Vec::new();
    let mut curr = dst;
    while curr != src {
        node_path.push(curr as i32);
        edge_indices.push(prev_edge[curr] as i32);
        curr = prev_node[curr];
    }
    node_path.push(src as i32);
    node_path.reverse();
    edge_indices.reverse();

    list!(
        found = true,
        node_path = node_path,
        edge_indices = edge_indices,
        total_time_s = dist[dst],
        total_length_m = dist_len[dst]
    )
}

/// Extract reachable edges and nodes within cutoff time from an origin node.
///
/// @param n_nodes Total number of nodes.
/// @param head_num CSR head array.
/// @param to CSR destination array.
/// @param wt CSR travel time array (seconds).
/// @param wl CSR length array (meters).
/// @param src_node Origin node (0-indexed).
/// @param cutoff Travel time cutoff in seconds.
/// @export
#[extendr]
fn rust_isochrone_subgraph(
    n_nodes: i32,
    head_num: Vec<f64>,
    to: Vec<i32>,
    wt: Vec<f64>,
    wl: Vec<f64>,
    src_node: i32,
    cutoff: f64,
) -> List {
    let n = n_nodes as usize;
    let head: Vec<usize> = head_num.into_iter().map(|x| x as usize).collect();
    let to_u: Vec<usize> = to.into_iter().map(|x| x as usize).collect();
    let src = src_node as usize;

    if src >= n {
        return list!(
            reached_nodes = Vec::<i32>::new(),
            node_times = Vec::<f64>::new(),
            edge_from = Vec::<i32>::new(),
            edge_to = Vec::<i32>::new(),
            edge_fraction = Vec::<f64>::new()
        );
    }

    let mut dist = vec![f64::INFINITY; n];
    let mut done = vec![false; n];
    let mut ht: Vec<f64> = Vec::with_capacity(1024);
    let mut hv: Vec<usize> = Vec::with_capacity(1024);

    let push_heap = |ht: &mut Vec<f64>, hv: &mut Vec<usize>, time: f64, node: usize| {
        let mut j = ht.len();
        ht.push(time);
        hv.push(node);
        while j > 0 {
            let p = (j - 1) / 2;
            if ht[p] <= ht[j] {
                break;
            }
            ht.swap(p, j);
            hv.swap(p, j);
            j = p;
        }
    };

    let pop_heap = |ht: &mut Vec<f64>, hv: &mut Vec<usize>| -> (f64, usize) {
        let min_t = ht[0];
        let min_v = hv[0];
        let last_idx = ht.len() - 1;
        if last_idx > 0 {
            ht[0] = ht[last_idx];
            hv[0] = hv[last_idx];
            ht.truncate(last_idx);
            hv.truncate(last_idx);

            let size = ht.len();
            let mut i = 0;
            loop {
                let l = 2 * i + 1;
                let r = 2 * i + 2;
                let mut k = i;
                if l < size && ht[l] < ht[k] {
                    k = l;
                }
                if r < size && ht[r] < ht[k] {
                    k = r;
                }
                if k == i {
                    break;
                }
                ht.swap(i, k);
                hv.swap(i, k);
                i = k;
            }
        } else {
            ht.clear();
            hv.clear();
        }
        (min_t, min_v)
    };

    dist[src] = 0.0;
    push_heap(&mut ht, &mut hv, 0.0, src);

    while !ht.is_empty() {
        let (t, u) = pop_heap(&mut ht, &mut hv);
        if done[u] {
            continue;
        }
        done[u] = true;

        let start = head[u];
        let end = head[u + 1];

        for i in start..end {
            let v = to_u[i];
            let w = wt[i];

            let nt = t + w;
            if nt <= cutoff && nt < dist[v] {
                dist[v] = nt;
                push_heap(&mut ht, &mut hv, nt, v);
            }
        }
    }

    let mut reached_nodes: Vec<i32> = Vec::new();
    let mut node_times: Vec<f64> = Vec::new();
    for i in 0..n {
        if dist[i] <= cutoff {
            reached_nodes.push(i as i32);
            node_times.push(dist[i]);
        }
    }

    // Collect edges with partial or full reach (undirected: only a <= b)
    let mut edge_from: Vec<i32> = Vec::new();
    let mut edge_to: Vec<i32> = Vec::new();
    let mut edge_fraction: Vec<f64> = Vec::new();
    let mut edge_length: Vec<f64> = Vec::new();
    let mut edge_reached_length: Vec<f64> = Vec::new();

    for u in 0..n {
        let t_u = dist[u];
        let rem_u = (cutoff - t_u).max(0.0);

        let start = head[u];
        let end = head[u + 1];
        for i in start..end {
            let v = to_u[i];
            if u <= v {
                let t_v = dist[v];
                let rem_v = (cutoff - t_v).max(0.0);
                let w = wt[i];
                let l = wl[i];

                let frac = if w <= 0.0 {
                    if t_u <= cutoff || t_v <= cutoff { 1.0 } else { 0.0 }
                } else {
                    let fu = if t_u <= cutoff { rem_u / w } else { 0.0 };
                    let fv = if t_v <= cutoff { rem_v / w } else { 0.0 };
                    (fu + fv).min(1.0)
                };

                if frac > 0.0 {
                    edge_from.push(u as i32);
                    edge_to.push(v as i32);
                    edge_fraction.push(frac);
                    edge_length.push(l);
                    edge_reached_length.push(l * frac);
                }
            }
        }
    }

    list!(
        reached_nodes = reached_nodes,
        node_times = node_times,
        edge_from = edge_from,
        edge_to = edge_to,
        edge_fraction = edge_fraction,
        edge_length = edge_length,
        edge_reached_length = edge_reached_length
    )
}

/// Compute cumulative POI accessibility for target nodes in parallel.
///
/// @param n_nodes Total number of nodes.
/// @param head_num CSR head array.
/// @param to CSR destination array.
/// @param wt CSR travel time array (seconds).
/// @param target_nodes Indices of nodes to compute accessibility for (0-indexed).
/// @param poi_nodes Vector of node indices where POIs are situated.
/// @param poi_weights Vector of weights/counts for each POI node.
/// @param cutoff Travel time cutoff in seconds.
/// @param num_threads Number of worker threads (0 = auto-detect).
/// @export
#[extendr]
fn rust_compute_access_multi(
    n_nodes: i32,
    head_num: Vec<f64>,
    to: Vec<i32>,
    wt: Vec<f64>,
    target_nodes: Vec<i32>,
    poi_nodes: Vec<i32>,
    poi_weights: Vec<f64>,
    cutoff: f64,
    num_threads: i32,
) -> List {
    let n = n_nodes as usize;
    let head: Vec<usize> = head_num.into_iter().map(|x| x as usize).collect();
    let to_u: Vec<usize> = to.into_iter().map(|x| x as usize).collect();
    let targets: Vec<usize> = target_nodes.into_iter().map(|x| x as usize).collect();

    // Build dense POI weight map
    let mut poi_map = vec![0.0f64; n];
    for (&node_idx, &weight) in poi_nodes.iter().zip(poi_weights.iter()) {
        let u = node_idx as usize;
        if u < n {
            poi_map[u] += weight;
        }
    }

    let compute_fn = || {
        targets
            .par_iter()
            .map_init(
                || DijkstraScratch::new(n),
                |scratch, &src| {
                    if src >= n {
                        return (f64::NAN, f64::NAN);
                    }
                    scratch.next_run();
                    let run = scratch.run;

                    scratch.dt[src] = 0.0;
                    scratch.stamp[src] = run;
                    scratch.ht.clear();
                    scratch.hv.clear();
                    scratch.push_heap(0.0, src);

                    let inf = f64::INFINITY;
                    let mut cum_weight = 0.0f64;
                    let mut min_time_s = f64::NAN;

                    while !scratch.ht.is_empty() {
                        let (t, u) = scratch.pop_heap();
                        if scratch.done[u] == run {
                            continue;
                        }
                        scratch.done[u] = run;

                        let w_poi = poi_map[u];
                        if w_poi > 0.0 {
                            cum_weight += w_poi;
                            if min_time_s.is_nan() {
                                min_time_s = t;
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

                    (cum_weight, min_time_s)
                },
            )
            .collect::<Vec<(f64, f64)>>()
    };

    let results = if num_threads > 0 {
        let pool = rayon::ThreadPoolBuilder::new()
            .num_threads(num_threads as usize)
            .build();
        match pool {
            Ok(p) => p.install(compute_fn),
            Err(_) => compute_fn(),
        }
    } else {
        compute_fn()
    };

    let mut counts = Vec::with_capacity(results.len());
    let mut min_times = Vec::with_capacity(results.len());
    for (cnt, tm) in results {
        counts.push(cnt);
        min_times.push(tm);
    }

    list!(
        accessible_count = counts,
        min_time_s = min_times
    )
}

// Module definition
extendr_module! {
    mod walkability;
    fn rust_build_csr;
    fn rust_compute_reachable_length;
    fn rust_compute_circuity_sample;
    fn rust_shortest_path;
    fn rust_isochrone_subgraph;
    fn rust_compute_access_multi;
}
