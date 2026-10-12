# Topological and Health Diagnosis for Street Networks

Evaluates the topological connectivity, dangling nodes, potential
undershoots, and component fragmentation of a user-supplied street
network before building the routing graph. This function does not alter
geometries, leaving repair decisions to the user.

## Usage

``` r
walk_diagnose_network(data, snap_search_radius_m = 10, crs = NULL)
```

## Arguments

- data:

  An `sf` object containing `LINESTRING` or `MULTILINESTRING` street
  segments.

- snap_search_radius_m:

  Maximum distance in meters to search for potential undershoots
  (unconnected ends located near another segment). Default is 10.0
  meters.

- crs:

  Optional target metric CRS (e.g. EPSG code or proj4string). If
  provided, `data` is transformed to this CRS before distance
  calculations.

## Value

A `walk_diagnosis` S3 object containing:

- summary:

  Tibble with diagnostic statistics.

- components:

  Table of detected connected components and their total lengths.

- undershoots:

  `sf` point collection of suspicious dangling endpoints.

- isolated_edges:

  `sf` line collection of edges not belonging to the giant component.

- data:

  Original spatial line data.

- search_radius_m:

  The search radius parameter used.

## Examples

``` r
data(streets_cusco)
diag <- walk_diagnose_network(streets_cusco, snap_search_radius_m = 5)
print(diag)
#> 
#> ── Walkability Network Health Diagnosis ────────────────────────────────────────
#> ✔ Total network analyzed: 484 segments (40.0 km)
#> ✔ Total components detected: 125
#> • Giant (main) component: 68.3% of network (27.3 km)
#> ! Detected 124 disconnected components / islands (12.69 km, 31.7% of network).
#> ℹ Identified 81 potential undershoots (dangling ends located <= 5 m from another street).
#> ! Recommendation: You can fix these by running walk_build_network(..., repair =
#>   TRUE, snap_tolerance_m =
#> 5
#> ).
#> 
#> Run `plot(diagnosis)` to inspect isolated segments and undershoots on a map.
```
