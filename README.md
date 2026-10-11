
<!-- README.md is generated from README.Rmd. Please edit that file -->

# walkability

<!-- badges: start -->

[![R-CMD-check](https://img.shields.io/badge/R--CMD--check-passing-brightgreen)](https://github.com/walkability/walkability)
[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust
Engine](https://img.shields.io/badge/Rust-Rayon%20Multi--threaded-orange.svg)](https://www.rust-lang.org/)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html)
<!-- badges: end -->

> **Quantify, diagnose, and map 10-minute pedestrian reach across urban
> street networks at native CPU speed.**

`walkability` computes the **reachable walkable network length within a
10-minute walk** (~750 m at 4.5 km/h) for every junction in a city.
Designed for urban planners and researchers, it solves two major
bottlenecks in pedestrian analytics: slow routing over massive street
graphs and geometric digitization biases, using a multi-threaded
**Rust** kernel with exact partial-edge credits.

<p align="center">

<img src="man/figures/curitiba_reach.png" width="600" alt="Reachable walkable network length in Curitiba rendered with viridis colormap">
<br> <em>Reachable network length in Curitiba. Yellow highlights dense,
highly permeable pedestrian districts; dark purple marks cul-de-sacs and
fragmented outskirts.</em>
</p>

------------------------------------------------------------------------

## Quickstart (60 Seconds)

### Installation

Install the development version from GitHub or local source:

``` r
# install.packages("pak")
pak::pak("walkability/walkability")
```

### Reproducible Minimal Example

``` r
library(walkability)
library(sf)

# 1. Create a minimal 2x2 street grid (100 m spacing)
lines <- st_sfc(
  st_linestring(rbind(c(0, 0), c(100, 0))),
  st_linestring(rbind(c(100, 0), c(100, 100))),
  st_linestring(rbind(c(100, 100), c(0, 100))),
  st_linestring(rbind(c(0, 100), c(0, 0))),
  crs = 32722
)
streets <- st_as_sf(data.frame(id = 1:4), geometry = lines)

# 2. Build graph network & compute 10-minute pedestrian reach (Rust)
net   <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)
reach <- walk_compute_reach(net, cutoff_s = 600.0, verbose = FALSE)

# 3. View results
reach
```

``` text
── Walkability Reachable Network Length ─────────────────────────────
v Isochrone Budget: 10.0 minutes (~750 m at 4.5 km/h)
v Evaluated Nodes: 4
* Average Reach: 0.40 km
* Highest Reach: 0.40 km
* Lowest Reach: 0.40 km
* 5th-95th percentile: 0.4 - 0.4 km
```

------------------------------------------------------------------------

## Key Capabilities

- **[Non-destructive Topological
  Diagnosis](vignettes/walkability-guide.Rmd)**:
  `walk_diagnose_network()` inspects user street files, flags isolated
  islands, and locates near-miss *undershoots* without mutating
  geometries.
- **[Controlled Geometric Repair](vignettes/walkability-guide.Rmd)**:
  `walk_build_network()` empowers users to choose whether to planarize
  crossings and snap dangling endpoints at specified tolerances.
- **[Exact Partial-Edge Dijkstra in
  Rust](vignettes/metodologia-y-supuestos.Rmd)**: `walk_compute_reach()`
  computes exact fractional contributions for boundary edges across all
  CPU cores with zero heap reallocations.
- **[Publication-Ready Maps](vignettes/walkability-guide.Rmd)**:
  `walk_plot_reach()` renders clean `ggplot2` visualizations with
  2nd–98th percentile scaling and ascending layer stacking.
- **[Route Directness & Circuity](vignettes/walkability-guide.Rmd)**:
  `walk_compute_circuity()` evaluates detour ratios between network
  shortest paths and Euclidean distance.

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
Assumptions](vignettes/metodologia-y-supuestos.Rmd) guide for details.*

------------------------------------------------------------------------

## Documentation & Vignettes

- **[Guía de Inicio Rápido](vignettes/walkability-guide.Rmd)**: Complete
  step-by-step workflow with user-provided datasets and diagnostic
  plots.
- **[Metodología, Algoritmo Dijkstra en Rust y
  Supuestos](vignettes/metodologia-y-supuestos.Rmd)**: Mathematical
  derivation of the partial-edge rule, CSR representation, and 11
  modeling limitations.
- **[Resultados de Referencia en
  Ciudades](vignettes/ciudades-referencia.Rmd)**: Benchmark findings and
  verified network statistics for Curitiba, Maringá, and São Paulo.

------------------------------------------------------------------------

## Citation & License

To cite `walkability` in publications:

``` text
Walkability Authors (2026). walkability: Urban Walkability and Active Transit Network Analysis. 
R package version 0.1.0. https://github.com/walkability/walkability
```

Distributed under the [MIT License](LICENSE).
