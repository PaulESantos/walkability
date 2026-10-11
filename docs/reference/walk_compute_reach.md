# Compute Reachable Walkable Network Length Metric

Computes the total walkable network length lying within each node's
isochrone (default 10-minute walk at 4.5 km/h, ~750 m budget). The
calculation runs in parallel using compiled Rust and applies the exact
partial-edge credit rule, crediting crossing frontier edges for only
their reachable fraction.

## Usage

``` r
walk_compute_reach(
  network,
  cutoff_s = 600,
  target = c("largest_component", "all"),
  n_threads = 0,
  verbose = TRUE
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- cutoff_s:

  Walking time budget in seconds (default is 600.0 seconds = 10
  minutes).

- target:

  Character string. Either `"largest_component"` (default) to compute
  only for nodes in the primary connected component, or `"all"`.

- n_threads:

  Number of CPU threads to use in parallel (0 = auto-detect all
  available cores).

- verbose:

  Logical. If `TRUE`, prints summary percentiles and runtime.

## Value

A `walk_reach` S3 object containing:

- nodes:

  `sf` points table augmented with `reachable_length_m` and
  `reachable_length_km`.

- edges:

  `sf` lines table augmented with `reachable_length_km` (mean of
  endpoints).

- summary:

  Summary statistics (min, mean, max, 5th, 95th percentiles).

- cutoff_s:

  The time cutoff used.

- network:

  The input `walk_network` object.

## Examples

``` r
if (FALSE) { # \dontrun{
reach <- walk_compute_reach(net, cutoff_s = 600)
print(reach)
plot(reach)
} # }
```
