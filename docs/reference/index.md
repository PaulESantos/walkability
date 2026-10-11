# Package index

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
