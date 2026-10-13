# Package index

## Sample Street Networks

Real-world OpenStreetMap walkable networks for benchmark cities in Peru.

- [`streets_cusco`](https://paulesantos.github.io/walkability/reference/streets_cusco.md)
  : Walkable Street Network of Cusco (Historic Center)
- [`streets_lima`](https://paulesantos.github.io/walkability/reference/streets_lima.md)
  : Walkable Street Network of Lima (Historic Center / Damero de
  Pizarro)
- [`streets_arequipa`](https://paulesantos.github.io/walkability/reference/streets_arequipa.md)
  : Walkable Street Network of Arequipa (Historic Center / Yanahuara)

## Topological Diagnostics

Inspect user-supplied street networks for connectivity, dead ends, and
undershoots without mutating geometries.

- [`walk_diagnose_network()`](https://paulesantos.github.io/walkability/reference/walk_diagnose_network.md)
  : Topological and Health Diagnosis for Street Networks
- [`print(`*`<walk_diagnosis>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_diagnosis.md)
  : Print Method for Street Network Diagnosis
- [`plot(`*`<walk_diagnosis>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_diagnosis.md)
  : Plot Method for Street Network Diagnosis

## Network Construction & Repair

Convert spatial vector data into pedestrian routing graphs with
user-controlled snapping and planarization.

- [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md)
  : Build Walkable Graph Network from Street Data
- [`print(`*`<walk_network>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_network.md)
  : Print Method for Walk Network

## Walkability & Reach Metrics

Multi-threaded isochrone reachable length calculations and route
directness evaluation.

- [`walk_compute_reach()`](https://paulesantos.github.io/walkability/reference/walk_compute_reach.md)
  : Compute Reachable Walkable Network Length Metric
- [`print(`*`<walk_reach>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_reach.md)
  : Print Method for Walk Reach Metric
- [`plot(`*`<walk_reach>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_reach.md)
  : Plot Method for Walk Reach Object
- [`walk_compute_circuity()`](https://paulesantos.github.io/walkability/reference/walk_compute_circuity.md)
  : Compute Network Circuity (Detour Ratio) for Sampled Junctions

## Optimal Pedestrian Routing

Single-pair point-to-point shortest path routing across the street
network using compiled Rust Dijkstra.

- [`walk_shortest_path()`](https://paulesantos.github.io/walkability/reference/walk_shortest_path.md)
  : Compute Shortest Pedestrian Path Between Two Locations
- [`print(`*`<walk_path>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_path.md)
  : Print Method for Walk Path
- [`plot(`*`<walk_path>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_path.md)
  : Plot Method for Walk Path

## Isochrones & Reachable Envelopes

Multi-threshold concave hull polygons and corridor envelopes for
walkable service areas.

- [`walk_isochrone()`](https://paulesantos.github.io/walkability/reference/walk_isochrone.md)
  : Compute Pedestrian Isochrone Polygons and Reachable Subgraphs
- [`print(`*`<walk_isochrone>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_isochrone.md)
  : Print Method for Walk Isochrone
- [`plot(`*`<walk_isochrone>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_isochrone.md)
  : Plot Method for Walk Isochrone

## Network Morphology & Intersection Density

Node valence classification, cul-de-sacs, T-junctions, crossroads, and
intersection density.

- [`walk_intersection_density()`](https://paulesantos.github.io/walkability/reference/walk_intersection_density.md)
  : Compute Intersection Density and Street Network Morphology
- [`print(`*`<walk_morphology>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_morphology.md)
  : Print Method for Walk Morphology
- [`plot(`*`<walk_morphology>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_morphology.md)
  : Plot Method for Walk Morphology

## Facility & POI Accessibility

Multi-threaded cumulative accessibility to urban amenities (schools,
health, transit) within walking time budgets.

- [`walk_compute_access()`](https://paulesantos.github.io/walkability/reference/walk_compute_access.md)
  : Compute Cumulative Walkable Accessibility to Points of Interest
  (POIs)
- [`print(`*`<walk_access>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_access.md)
  : Print Method for Walk Access
- [`plot(`*`<walk_access>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_access.md)
  : Plot Method for Walk Access

## Intervention Scenarios & Street Closures

Simulate pedestrianization, street cuts, and compare before/after
walkability metrics.

- [`walk_scenario_close()`](https://paulesantos.github.io/walkability/reference/walk_scenario_close.md)
  : Simulate Street Closure or Pedestrianization Intervention Scenario
- [`walk_compare_scenarios()`](https://paulesantos.github.io/walkability/reference/walk_compare_scenarios.md)
  : Compare Baseline and Intervention Scenarios
- [`print(`*`<walk_comparison>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_comparison.md)
  : Print Method for Walk Comparison
- [`plot(`*`<walk_comparison>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_comparison.md)
  : Plot Method for Walk Comparison

## Centrality & Network Betweenness

Calculate edge betweenness centrality, identify structural bottlenecks,
and evaluate flow redistribution under street closures.

- [`walk_betweenness()`](https://paulesantos.github.io/walkability/reference/walk_betweenness.md)
  : Street Network Edge Betweenness Centrality
- [`print(`*`<walk_betweenness>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_betweenness.md)
  : Print Method for Walk Betweenness
- [`plot(`*`<walk_betweenness>`*`)`](https://paulesantos.github.io/walkability/reference/plot.walk_betweenness.md)
  : Plot Method for Walk Betweenness
- [`walk_scenario_betweenness()`](https://paulesantos.github.io/walkability/reference/walk_scenario_betweenness.md)
  : Simulate Scenario Closures and Evaluate Betweenness Re-routing
- [`print(`*`<walk_scenario_betweenness>`*`)`](https://paulesantos.github.io/walkability/reference/print.walk_scenario_betweenness.md)
  : Print Method for Walk Scenario Betweenness

## Graph Interoperability

Seamless conversion to standard R spatial graph classes (sfnetworks,
tidygraph).

- [`as_sfnetwork()`](https://paulesantos.github.io/walkability/reference/as_sfnetwork.md)
  : Convert Walk Network to sfnetworks Graph
- [`as_tidygraph()`](https://paulesantos.github.io/walkability/reference/as_tidygraph.md)
  : Convert Walk Network to tidygraph tbl_graph

## Interactive Web Application (mapgl)

GPU-accelerated MapLibre GL interactive dashboard for real-time reach,
isochrones, routing, and scenario analysis.

- [`walk_app()`](https://paulesantos.github.io/walkability/reference/walk_app.md)
  : Launch the Interactive Walkability Application

## Cartographic Visualizations

Publication-grade ggplot2 maps and minimalist cartographic themes.

- [`walk_plot_reach()`](https://paulesantos.github.io/walkability/reference/walk_plot_reach.md)
  : Plot Reachable Walkable Network Length Map
- [`walk_plot_diagnosis()`](https://paulesantos.github.io/walkability/reference/walk_plot_diagnosis.md)
  : Plot Street Network Topological Diagnosis
- [`theme_walkability()`](https://paulesantos.github.io/walkability/reference/theme_walkability.md)
  : Modern Minimalist Cartographic Theme for Walkability

## Data Ingestion

Automated street network acquisition from OpenStreetMap and Overture
Maps.

- [`walk_download_osm()`](https://paulesantos.github.io/walkability/reference/walk_download_osm.md)
  : Download OpenStreetMap Street Network Data
- [`walk_download_overture_bbox()`](https://paulesantos.github.io/walkability/reference/walk_download_overture_bbox.md)
  : Query Overture Maps Data via DuckDB

## Rust Acceleration Kernels

Low-level compiled Rust routines for CSR conversion and parallel
Dijkstra search.

- [`rust_build_csr()`](https://paulesantos.github.io/walkability/reference/rust_build_csr.md)
  : Build Compressed Sparse Row (CSR) graph representation. Drops
  self-loops, collapses parallel edges to minimum travel time, and
  returns CSR structures along with connected component analysis.
- [`rust_compute_reachable_length()`](https://paulesantos.github.io/walkability/reference/rust_compute_reachable_length.md)
  : Compute reachable walkable network length in parallel for a set of
  target nodes.
- [`rust_compute_circuity_sample()`](https://paulesantos.github.io/walkability/reference/rust_compute_circuity_sample.md)
  : Compute detour ratio (circuity) for sampled origin-destination
  pairs.
- [`rust_shortest_path()`](https://paulesantos.github.io/walkability/reference/rust_shortest_path.md)
  : Compute shortest path between source and target nodes using
  Dijkstra.
- [`rust_isochrone_subgraph()`](https://paulesantos.github.io/walkability/reference/rust_isochrone_subgraph.md)
  : Extract reachable edges and nodes within cutoff time from an origin
  node.
- [`rust_compute_access_multi()`](https://paulesantos.github.io/walkability/reference/rust_compute_access_multi.md)
  : Compute cumulative POI accessibility for target nodes in parallel.
