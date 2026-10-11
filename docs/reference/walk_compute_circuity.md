# Compute Network Circuity (Detour Ratio) for Sampled Junctions

Evaluates path directness by comparing network shortest-path distances
against Euclidean straight-line distances. High circuity signifies
indirect, circuitous street patterns and cul-de-sacs.

## Usage

``` r
walk_compute_circuity(network, sample_size = 500, cutoff_s = 600)
```

## Arguments

- network:

  A `walk_network` object.

- sample_size:

  Number of random junctions to sample. Default is 500.

- cutoff_s:

  Walking time budget in seconds (default is 600.0).

## Value

A `tibble` with node IDs and calculated detour ratios.
