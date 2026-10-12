# Changelog

## walkability 0.1.0

- Initial release of the `walkability` R package.
- Implemented multi-threaded Dijkstra kernel in Rust using `rextendr`
  and `rayon` with exact partial-edge credits.
- Added
  [`walk_diagnose_network()`](https://paulesantos.github.io/walkability/reference/walk_diagnose_network.md)
  for non-destructive street network health inspections (component
  connectivity, dead ends, and undershoot detection).
- Added
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md)
  with user-controlled snapping and planarization.
- Added
  [`walk_compute_reach()`](https://paulesantos.github.io/walkability/reference/walk_compute_reach.md)
  for 10-minute walkable network length calculations.
- Added
  [`walk_compute_circuity()`](https://paulesantos.github.io/walkability/reference/walk_compute_circuity.md)
  for detour ratio evaluation.
- Added
  [`walk_plot_reach()`](https://paulesantos.github.io/walkability/reference/walk_plot_reach.md)
  and
  [`walk_plot_diagnosis()`](https://paulesantos.github.io/walkability/reference/walk_plot_diagnosis.md)
  for publication-grade cartography using `ggplot2` and `viridis`.
- Added
  [`walk_shortest_path()`](https://paulesantos.github.io/walkability/reference/walk_shortest_path.md)
  with compiled Rust Dijkstra for single-pair routing, path geometry
  reconstruction, travel time, and detour circuity.
- Added
  [`walk_isochrone()`](https://paulesantos.github.io/walkability/reference/walk_isochrone.md)
  for multi-threshold walkable polygon envelopes (concave hull and
  corridor buffers) and sub-network extraction.
- Added
  [`walk_intersection_density()`](https://paulesantos.github.io/walkability/reference/walk_intersection_density.md)
  for junction valence morphology (cul-de-sacs, T-junctions, crossroads)
  and intersection density per km².
- Added
  [`walk_compute_access()`](https://paulesantos.github.io/walkability/reference/walk_compute_access.md)
  for multi-threaded cumulative accessibility to urban facilities/POIs
  (schools, clinics, transport) in parallel Rust.
- Added
  [`walk_scenario_close()`](https://paulesantos.github.io/walkability/reference/walk_scenario_close.md)
  and
  [`walk_compare_scenarios()`](https://paulesantos.github.io/walkability/reference/walk_compare_scenarios.md)
  for evaluating street pedestrianization and closure impacts.
- Added
  [`as_sfnetwork()`](https://paulesantos.github.io/walkability/reference/as_sfnetwork.md)
  and
  [`as_tidygraph()`](https://paulesantos.github.io/walkability/reference/as_tidygraph.md)
  for seamless interoperability with the `sfnetworks` and `tidygraph`
  spatial network ecosystems.
