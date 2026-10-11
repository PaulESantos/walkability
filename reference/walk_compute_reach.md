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
  time_min = 10,
  cutoff_s = NULL,
  target = c("largest_component", "all"),
  n_threads = 0,
  verbose = TRUE
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- time_min:

  Walking time budget in minutes (default is 10.0 minutes). Users can
  freely customize this parameter; for smaller neighborhoods, compact
  districts, or localized analyses, values like 5.0 or 7.5 minutes can
  be used.

- cutoff_s:

  Optional walking time budget in seconds (e.g. 600.0). If specified, it
  overrides `time_min`.

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

- time_min:

  The time cutoff in minutes.

- cutoff_s:

  The time cutoff in seconds.

- network:

  The input `walk_network` object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Standard 10-minute walk reach
reach <- walk_compute_reach(net, time_min = 10)

# Short 5-minute neighborhood reach
reach_5m <- walk_compute_reach(net, time_min = 5)
print(reach_5m)
plot(reach_5m)
} # }
```
