# Extract reachable edges and nodes within cutoff time from an origin node.

Extract reachable edges and nodes within cutoff time from an origin
node.

## Usage

``` r
rust_isochrone_subgraph(n_nodes, head_num, to, wt, wl, src_node, cutoff)
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

- cutoff:

  Travel time cutoff in seconds.
