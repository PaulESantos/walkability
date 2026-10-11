# Changelog

## walkability 0.1.0

- Initial release of the `walkability` R package.
- Implemented multi-threaded Dijkstra kernel in Rust using `rextendr`
  and `rayon` with exact partial-edge credits.
- Added
  [`walk_diagnose_network()`](https://walkability.github.io/walkability/reference/walk_diagnose_network.md)
  for non-destructive street network health inspections (component
  connectivity, dead ends, and undershoot detection).
- Added
  [`walk_build_network()`](https://walkability.github.io/walkability/reference/walk_build_network.md)
  with user-controlled snapping and planarization.
- Added
  [`walk_compute_reach()`](https://walkability.github.io/walkability/reference/walk_compute_reach.md)
  for 10-minute walkable network length calculations.
- Added
  [`walk_compute_circuity()`](https://walkability.github.io/walkability/reference/walk_compute_circuity.md)
  for detour ratio evaluation.
- Added
  [`walk_plot_reach()`](https://walkability.github.io/walkability/reference/walk_plot_reach.md)
  and
  [`walk_plot_diagnosis()`](https://walkability.github.io/walkability/reference/walk_plot_diagnosis.md)
  for publication-grade cartography using `ggplot2` and `viridis`.
- Added automated data ingestion tools
  ([`walk_download_osm()`](https://walkability.github.io/walkability/reference/walk_download_osm.md)
  and
  [`walk_download_overture_bbox()`](https://walkability.github.io/walkability/reference/walk_download_overture_bbox.md)).
