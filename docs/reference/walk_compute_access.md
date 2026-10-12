# Compute Cumulative Walkable Accessibility to Points of Interest (POIs)

Computes cumulative pedestrian accessibility from each network junction
to urban facilities (e.g. schools, health centers, pharmacies, public
transit stops) within a walking time budget (default 10 minutes at 4.5
km/h). Uses parallel compiled Rust to evaluate hundreds of thousands of
shortest paths across CPU cores.

## Usage

``` r
walk_compute_access(
  network,
  pois,
  time_min = 10,
  category_col = NULL,
  weight_col = NULL,
  target = c("largest_component", "all"),
  n_threads = 0,
  verbose = TRUE
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- pois:

  An `sf` points collection containing destination facilities/POIs.

- time_min:

  Walking time threshold in minutes (default 10.0 minutes).

- category_col:

  Optional column name in `pois` indicating facility category (e.g.
  `"amenity"`, `"category"`, or `"type"`). If provided, calculates
  separate accessibility counts for each unique category.

- weight_col:

  Optional column name in `pois` indicating facility weight/capacity.
  Default is `NULL` (each POI counts as 1.0).

- target:

  Character string: `"largest_component"` (default) to evaluate nodes in
  the primary connected component, or `"all"`.

- n_threads:

  Number of CPU threads (0 = auto-detect all available cores).

- verbose:

  Logical. If `TRUE`, prints execution progress and summary.

## Value

A `walk_access` S3 object containing:

- nodes:

  `sf` points table augmented with columns for cumulative counts and
  minimum walking times.

- summary:

  Summary statistics table per category.

- time_min:

  The evaluated walking budget in minutes.

- pois:

  The original POI points mapped to network nodes.

- network:

  The input `walk_network`.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
sample_pois <- net$nodes[net$nodes$is_giant, ][seq(1, 100, by = 20), ]
acc <- walk_compute_access(net, pois = sample_pois, time_min = 5, verbose = FALSE)
print(acc)
#> 
#> ── Walkability Cumulative POI Accessibility ────────────────────────────────────
#> ✔ Isochrone Threshold: 5.0 minutes
#> ✔ Facilities Evaluated: 5
#> ✔ Evaluated Junctions: 249
#> • [all_pois] Avg reachable: 0.6 | Max: 2 | Reachability coverage: 50.2% of
#>   network
```
