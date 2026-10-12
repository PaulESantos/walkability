# Simulate Street Closure or Pedestrianization Intervention Scenario

Creates an independent copy of a walkable street network with specified
street segments (edges) or junctions (nodes) removed (simulating street
cuts, construction, or pedestrianization). Reconstructs Compressed
Sparse Row topology and component connectivity using compiled Rust.

## Usage

``` r
walk_scenario_close(
  network,
  edge_indices = NULL,
  node_indices = NULL,
  name = "scenario_closure"
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- edge_indices:

  Integer vector of edge row indices to remove (1-indexed).

- node_indices:

  Optional integer vector of node indices whose attached edges will be
  removed.

- name:

  Descriptive character label for this intervention scenario.

## Value

A new `walk_network` S3 object representing the modified scenario, with
metadata storing the closed edges.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
cierre <- walk_scenario_close(net, edge_indices = c(5, 12), name = "Peatonalizacion Central")
print(cierre)
#> 
#> ── Walkability Network ─────────────────────────────────────────────────────────
#> ✔ Total nodes: 562 (Giant component: 249)
#> ✔ Total edges: 286 segments (27.2 km)
#> ✔ Walking speed: 4.5 km/h (1.25 m/s)
#> ✔ Connected components: 314
#> ✔ CRS: EPSG:32719
```
