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
  n_threads = 2L,
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

  Number of CPU threads to use in parallel, from 1 to 2. The default is
  2, the maximum permitted during CRAN checks.

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
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
reach <- walk_compute_reach(net, time_min = 5, verbose = FALSE)
print(reach)
#> 
#> ── Walkability Reachable Network Length ────────────────────────────────────────
#> ✔ Isochrone Budget: 5.0 minutes (~375 m at 4.5 km/h)
#> ✔ Evaluated Nodes: 249
#> • Average Reach: 2.29 km
#> • Highest Reach: 4.91 km
#> • Lowest Reach: 0.37 km
#> • 5th-95th percentile: 0.4 - 4.4 km
```
