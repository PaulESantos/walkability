# walkability 0.1.0

* Initial release of the `walkability` R package.
* Implemented multi-threaded Dijkstra kernel in Rust using `rextendr` and `rayon` with exact partial-edge credits.
* Added `walk_diagnose_network()` for non-destructive street network health inspections (component connectivity, dead ends, and undershoot detection).
* Added `walk_build_network()` with user-controlled snapping and planarization.
* Added `walk_compute_reach()` for 10-minute walkable network length calculations.
* Added `walk_compute_circuity()` for detour ratio evaluation.
* Added `walk_plot_reach()` and `walk_plot_diagnosis()` for publication-grade cartography using `ggplot2` and `viridis`.
* Added automated data ingestion tools (`walk_download_osm()` and `walk_download_overture_bbox()`).
