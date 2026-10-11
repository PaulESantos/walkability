# Compute reachable walkable network length in parallel for a set of target nodes.

Compute reachable walkable network length in parallel for a set of
target nodes.

## Usage

``` r
rust_compute_reachable_length(
  n_nodes,
  head_num,
  to,
  wt,
  wl,
  target_nodes,
  cutoff,
  num_threads
)
```

## Arguments

- n_nodes:

  Total number of nodes in graph.

- head_num:

  CSR head array.

- to:

  CSR destination nodes.

- wt:

  CSR travel times (seconds).

- wl:

  CSR lengths (meters).

- target_nodes:

  Indices of nodes to compute metric for (0-indexed).

- cutoff:

  Walk travel-time budget (seconds, default 600.0 = 10 min).

- num_threads:

  Number of worker threads (0 = auto-detect all CPU cores).
