# Compute Shortest Pedestrian Path Between Two Locations

Finds the optimal walking route between an origin and destination across
the street graph using Dijkstra's algorithm compiled in Rust. Supports
node IDs, numeric coordinate vectors `c(x, y)`, or `sf` point
geometries.

## Usage

``` r
walk_shortest_path(network, from, to)
```

## Arguments

- network:

  A `walk_network` object created by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- from:

  Origin location: either an integer node index, a numeric vector
  `c(x, y)` in the network's metric CRS, or an `sf` POINT.

- to:

  Destination location: either an integer node index, a numeric vector
  `c(x, y)` in the network's metric CRS, or an `sf` POINT.

## Value

A `walk_path` S3 object containing:

- path_sf:

  `sf` object with the route geometry (`LINESTRING`) and attributes.

- nodes_sf:

  `sf` points along the path in traversed order.

- node_ids:

  Sequence of node IDs visited.

- distance_m:

  Total walking route distance in meters.

- time_s:

  Total travel time in seconds at the network walking speed.

- time_min:

  Total travel time in minutes.

- circuity:

  Detour ratio (network path distance / straight-line Euclidean
  distance).

- from_node:

  Resolved origin node index.

- to_node:

  Resolved destination node index.

- network:

  The input `walk_network`.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
orig <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
dest <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[50, 1:2]
p <- walk_shortest_path(net, from = orig, to = dest)
print(p)
#> 
#> ── Walkability Shortest Path ───────────────────────────────────────────────────
#> ✔ Origin Node: 0 -> Destination Node: 75
#> ✔ Nodes Visited: 13
#> • Walking Distance: 858.2 m (0.86 km)
#> • Estimated Time: 11.4 min (687 s)
#> • Route Circuity: 1.256
```
