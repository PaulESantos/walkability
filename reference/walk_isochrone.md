# Compute Pedestrian Isochrone Polygons and Reachable Subgraphs

Generates spatial polygon isochrones (concave hulls or buffered
envelopes) and extracts the exact reachable street network from an
origin location for specified walking time budgets (e.g. 5, 10, 15
minutes).

## Usage

``` r
walk_isochrone(
  network,
  origin,
  time_min = c(5, 10, 15),
  method = c("concave", "buffer"),
  buffer_m = 25,
  concave_ratio = 0.3,
  rings = TRUE
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- origin:

  Origin location: an integer node ID, coordinate vector `c(x, y)`, or
  an `sf` POINT.

- time_min:

  Numeric vector of walking time thresholds in minutes (e.g.
  `c(5, 10, 15)` or `10.0`).

- method:

  Polygon generation technique: `"concave"` for concave hull envelopes
  or `"buffer"` for street network buffering.

- buffer_m:

  Buffer width in meters applied along reachable edges when synthesizing
  pedestrian walkable corridors (default 25.0 m).

- concave_ratio:

  Ratio parameter passed to
  [`sf::st_concave_hull()`](https://r-spatial.github.io/sf/reference/geos_unary.html)
  (0 to 1, default 0.3).

- rings:

  Logical. If `TRUE` (default), multi-threshold polygons are transformed
  into mutually disjoint, non-overlapping concentric rings (e.g. 0-5
  min, 5-10 min, 10-15 min) via topological differences, avoiding
  polygon occlusion. Cumulative envelopes are still preserved in the
  `cumulative_polygons` element.

## Value

A `walk_isochrone` S3 object containing:

- polygons:

  `sf` polygons representing the isochrones (rings or cumulative).

- cumulative_polygons:

  `sf` polygons with full cumulative envelopes.

- edges:

  `sf` lines of all reached street segments with travel time.

- origin:

  `sf` point of the resolved origin node.

- time_min:

  The evaluated time thresholds.

- rings:

  Logical indicating whether disjoint rings were generated.

- network:

  The input `walk_network`.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
orig <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
iso <- walk_isochrone(net, origin = orig, time_min = c(5, 10), rings = TRUE)
print(iso)
#> 
#> ── Walkability Isochrones ──────────────────────────────────────────────────────
#> ✔ Origin Node: 0
#> ✔ Enveloping Method: concave
#> ✔ Topology Type: Non-overlapping concentric rings (Disjoint)
#> ✔ Cutoffs Evaluated: 5 min, 10 min
#> • [0 - 5 min] Reachable length: 3.04 km | Area: 0.31 km² | Edges: 53
#> • [5 - 10 min] Reachable length: 10.36 km | Area: 0.56 km² | Edges: 123
```
