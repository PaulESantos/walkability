# Build Compressed Sparse Row (CSR) graph representation. Drops self-loops, collapses parallel edges to minimum travel time, and returns CSR structures along with connected component analysis.

Build Compressed Sparse Row (CSR) graph representation. Drops
self-loops, collapses parallel edges to minimum travel time, and returns
CSR structures along with connected component analysis.

## Usage

``` r
rust_build_csr(n_nodes, u, v, wt, wl)
```

## Arguments

- n_nodes:

  Number of nodes in the graph (0-indexed: 0..n-1).

- u:

  From-node vector (0-indexed).

- v:

  To-node vector (0-indexed).

- wt:

  Travel time in seconds for each edge.

- wl:

  Physical length in meters for each edge.
