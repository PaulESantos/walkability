# Compute detour ratio (circuity) for sampled origin-destination pairs.

Circuity is defined as actual network shortest path distance divided by
Euclidean straight-line distance. Values close to 1.0 indicate highly
direct routes; higher values indicate circuitous paths and poor
permeability.

## Usage

``` r
rust_compute_circuity_sample(
  n_nodes,
  head_num,
  to,
  wt,
  wl,
  coords_x,
  coords_y,
  sample_nodes,
  cutoff
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

  CSR travel time array.

- wl:

  CSR length array.

- coords_x:

  Vector of node X coordinates (meters).

- coords_y:

  Vector of node Y coordinates (meters).

- sample_nodes:

  Nodes from which to measure circuity.

- cutoff:

  Travel time cutoff in seconds.
