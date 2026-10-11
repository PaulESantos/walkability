# Compute Network Circuity (Detour Ratio) for Sampled Junctions

Evaluates path directness by comparing network shortest-path distances
against Euclidean straight-line distances. High circuity signifies
indirect, circuitous street patterns and cul-de-sacs.

## Usage

``` r
walk_compute_circuity(
  network,
  sample_size = 500,
  time_min = 10,
  cutoff_s = NULL
)
```

## Arguments

- network:

  A `walk_network` object.

- sample_size:

  Number of random junctions to sample. Default is 500.

- time_min:

  Walking time budget in minutes (default is 10.0 minutes).

- cutoff_s:

  Optional walking time budget in seconds (default is `NULL`). If
  provided, it overrides `time_min`.

## Value

A `tibble` with node IDs and calculated detour ratios.
