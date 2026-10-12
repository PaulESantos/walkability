# walkability

> **Quantify, diagnose, and map 10-minute pedestrian reach across urban
> street networks at native CPU speed.**

`walkability` computes the **reachable walkable network length within a
10-minute walk** (~750 m at 4.5 km/h) for every junction in a city.
Designed for urban planners and researchers, it solves two major
bottlenecks in pedestrian analytics: slow routing over massive street
graphs and geometric digitization biases, using a multi-threaded
**Rust** kernel with exact partial-edge credits.

![Reachable walkable network length in Cusco rendered with viridis
colormap](reference/figures/cusco_reach.png)\
*Reachable network length in Cusco. Yellow highlights dense, highly
permeable pedestrian districts (Historic Center); dark purple marks
fragmented outskirts and steep hillsides.*

------------------------------------------------------------------------

## Quickstart

### Installation

Install the development version from GitHub:

``` r

# install.packages("pak")
pak::pak("PaulESantos/walkability")
```

### Reproducible Example with Real Urban Data

`walkability` includes real, curated street network datasets from
OpenStreetMap for **Cusco**, **Lima**, and **Arequipa**:

``` r

library(walkability)
library(sf)

# 1. Load real street network from Cusco (Historic Center, UTM 19S)
data(streets_cusco)

# 2. Build graph network & compute pedestrian reach (Rust)
net   <- walk_build_network(streets_cusco, walk_speed_kmh = 4.5, verbose = FALSE)
reach <- walk_compute_reach(net, time_min = 10, verbose = FALSE)

# 3. View results
reach
```

``` text
── Walkability Reachable Network Length ────────────────────────────────────────
✔ Isochrone Budget: 10.0 minutes (~750 m at 4.5 km/h)
✔ Evaluated Nodes: 249
• Average Reach: 8.75 km
• Highest Reach: 17.39 km
• Lowest Reach: 0.75 km
• 5th-95th percentile: 3.1 - 15.5 km
```

``` r

# 4. Point-to-point pedestrian routing & circuity
orig <- st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
dest <- st_coordinates(net$nodes[net$nodes$is_giant, ])[50, 1:2]
path <- walk_shortest_path(net, from = orig, to = dest)
path

# 5. Isochrone polygon generation (concave hull)
iso  <- walk_isochrone(net, origin = orig, time_min = c(5, 10))
iso

# 6. Urban intersection density & morphology
dens <- walk_intersection_density(net)
dens
```

------------------------------------------------------------------------

## Key Capabilities

- **Curated Real-World Datasets**: Out-of-the-box model networks for
  `streets_cusco`, `streets_lima`, and `streets_arequipa`.
- **Non-destructive Topological Diagnosis**:
  [`walk_diagnose_network()`](https://paulesantos.github.io/walkability/reference/walk_diagnose_network.md)
  inspects user street files, flags isolated islands, and locates
  near-miss *undershoots* without mutating geometries.
- **Controlled Geometric Repair**:
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md)
  empowers users to choose whether to planarize crossings and snap
  dangling endpoints at specified tolerances.
- **Exact Partial-Edge Dijkstra in Rust**:
  [`walk_compute_reach()`](https://paulesantos.github.io/walkability/reference/walk_compute_reach.md)
  computes exact fractional contributions for boundary edges across all
  CPU cores with zero heap reallocations.
- **Pedestrian Point-to-Point Routing**:
  [`walk_shortest_path()`](https://paulesantos.github.io/walkability/reference/walk_shortest_path.md)
  extracts the exact shortest path geometry, travel time, and route
  circuity detour ratio.
- **Isochrone Polygons & Subgraphs**:
  [`walk_isochrone()`](https://paulesantos.github.io/walkability/reference/walk_isochrone.md)
  generates exact reachable network corridors and concave hull polygons.
- **Cumulative POI Accessibility**:
  [`walk_compute_access()`](https://paulesantos.github.io/walkability/reference/walk_compute_access.md)
  counts reachable amenities (schools, healthcare, transit) within
  travel time budgets using parallel Rust.
- **Urban Morphology & Intersection Metrics**:
  [`walk_intersection_density()`](https://paulesantos.github.io/walkability/reference/walk_intersection_density.md)
  classifies cul-de-sacs, 3-way T-junctions, 4-way crossings, and
  intersection density.
- **Intervention Scenario Simulation**:
  [`walk_scenario_close()`](https://paulesantos.github.io/walkability/reference/walk_scenario_close.md)
  and
  [`walk_compare_scenarios()`](https://paulesantos.github.io/walkability/reference/walk_compare_scenarios.md)
  model street cuts, closures, and pedestrianization.
- **Graph Interoperability**:
  [`as_sfnetwork()`](https://paulesantos.github.io/walkability/reference/as_sfnetwork.md)
  and
  [`as_tidygraph()`](https://paulesantos.github.io/walkability/reference/as_tidygraph.md)
  enable two-way workflows with `sfnetworks` and `tidygraph`.
- **Publication-Ready Maps**:
  [`walk_plot_reach()`](https://paulesantos.github.io/walkability/reference/walk_plot_reach.md)
  renders clean `ggplot2` visualizations with 2nd–98th percentile
  scaling and ascending layer stacking.

------------------------------------------------------------------------

## Scope & Limitations

- **Modeled speed**: Assumes a design walking speed of 4.5 km/h (1.25
  m/s). It measures structural street connectivity, not observed GPS
  pedestrian speeds.
- **Footway availability**: All non-motorway and non-trunk roads are
  modeled as walkable unless tagged as closed to pedestrians.
- **Planar topology**: Grade-separated intersections (overpasses) are
  treated as planar unless explicit elevation tags exist.

*Read the complete [Methodology and Model
Assumptions](https://paulesantos.github.io/walkability/articles/metodologia-y-supuestos.html)
guide for details.*

------------------------------------------------------------------------

## Documentation & Vignettes

- **[Guía de Inicio
  Rápido](https://paulesantos.github.io/walkability/articles/walkability-guide.html)**:
  Complete step-by-step workflow with user-provided datasets, network
  repair, and diagnostic plots.
- **[Metodología, Algoritmo Dijkstra en Rust y
  Supuestos](https://paulesantos.github.io/walkability/articles/metodologia-y-supuestos.html)**:
  Mathematical derivation of the partial-edge rule, CSR representation,
  and 11 modeling limitations.
- **[Resultados de Referencia en
  Ciudades](https://paulesantos.github.io/walkability/articles/ciudades-referencia.html)**:
  Benchmark findings and verified network statistics for Cusco,
  Arequipa, and Lima.

------------------------------------------------------------------------

## Citation & License

To cite `walkability` in publications:

``` text
Santos Andrade, P. E. (2026). walkability: Urban Walkability and Active Transit Network Analysis.
R package version 0.1.0. https://github.com/PaulESantos/walkability
```

Distributed under the [MIT
License](https://paulesantos.github.io/walkability/LICENSE).
