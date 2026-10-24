# Compute shortest path between source and target nodes using Dijkstra.

Compute shortest path between source and target nodes using Dijkstra.

## Usage

``` r
rust_shortest_path(n_nodes, head_num, to, wt, wl, src_node, dst_node)
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

- wl:

  CSR length array (meters).

- src_node:

  Origin node (0-indexed).

- dst_node:

  Destination node (0-indexed).

## Value

A named `list` with logical `found`, zero-based `node_path` and
`edge_indices` vectors, and numeric `total_time_s` and `total_length_m`.
When no path is found, paths are empty and totals are `NaN`.
