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

  Tibble with diagnostic statistics (segments, lengths, components,
  dangles, undershoots).

- components:

  Table of detected connected components and their total lengths.

- undershoots:

  `sf` point collection of suspicious dangling endpoints within
  `snap_search_radius_m` of another street, with column
  `dist_to_nearest_m`.

- isolated_edges:

  `sf` line collection of edges not belonging to the giant component.

- data:

  Original spatial line data.

- search_radius_m:

  The search radius parameter used.

## Details

### Concept: Undershoots

An **undershoot** occurs when a digitized street segment terminates just
short of intersecting or connecting with an adjacent road, leaving a
small metric gap. While legitimate dead ends (cul-de-sacs) naturally
exist in pedestrian networks, a dangling endpoint that lies suspiciously
close (within `snap_search_radius_m`) to another street is typically a
digitization or vectorization defect.

In `walk_diagnose_network()`, undershoots are identified in two stages:

1.  All dangling endpoints (nodes with topological degree = 1) are
    isolated across the network.

2.  The minimum Euclidean distance from each dangling endpoint to all
    other line geometries (excluding the incident segment itself) is
    computed. If this distance is less than or equal to
    `snap_search_radius_m`, the endpoint is flagged as a potential
    undershoot.

In pedestrian routing, even a gap of a few centimeters forms an
impassable barrier, artificially forcing detours or disconnecting
origins from destinations. Potential undershoots can be resolved during
network construction via
[`walk_build_network(..., repair = TRUE, snap_tolerance_m = ...)`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

### Concept: Isolated Edges

**Isolated edges** are street segments that belong to disconnected
components (subgraphs or "islands") outside of the primary **giant
component** (the largest contiguous connected network).

In `walk_diagnose_network()`, connectivity components are detected using
a fast disjoint-set (Union-Find) algorithm implemented in Rust:

1.  Endpoints are matched across lines using coordinate coincidence with
    1 mm precision.

2.  The giant component is determined as the component with the largest
    total network length.

3.  Any edge where neither endpoint connects to the giant component is
    labeled as an isolated edge.

Isolated fragments commonly arise from bounding box or polygon clipping
(cutting streets at administrative borders), gated communities, or
disjointed municipal data layers. When routing or computing isochrones,
any origin or destination snapped to an isolated edge will be
mathematically unreachable from the rest of the city (resulting in
infinite travel times).

### Visual Inspection

Diagnostic results can be inspected visually using `plot(diagnosis)` or
[`walk_plot_diagnosis()`](https://paulesantos.github.io/walkability/reference/walk_plot_diagnosis.md),
which renders the giant component in neutral tones, highlights isolated
edges in red, and marks potential undershoots with amber points.

## See also

[`walk_plot_diagnosis()`](https://paulesantos.github.io/walkability/reference/walk_plot_diagnosis.md),
[`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md)

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
