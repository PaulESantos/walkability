# Compute cumulative POI accessibility for target nodes in parallel.

Compute cumulative POI accessibility for target nodes in parallel.

## Usage

``` r
rust_compute_access_multi(
  n_nodes,
  head_num,
  to,
  wt,
  target_nodes,
  poi_nodes,
  poi_weights,
  cutoff,
  num_threads
)
```

## Arguments

- n_nodes:

  Total number of nodes.

- head_num:

  CSR head array.

- to:

  CSR destination array.

- wt:

  CSR travel time array (seconds).

- target_nodes:

  Indices of nodes to compute accessibility for (0-indexed).

- poi_nodes:

  Vector of node indices where POIs are situated.

- poi_weights:

  Vector of weights/counts for each POI node.

- cutoff:

  Travel time cutoff in seconds.

- num_threads:

  Number of worker threads (0 = auto-detect).
