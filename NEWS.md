# walkability 0.1.0

* Initial release of the `walkability` R package.
* Implemented multi-threaded Dijkstra kernel in Rust using `rextendr` and `rayon` with exact partial-edge credits.
* Added `walk_diagnose_network()` for non-destructive street network health inspections (component connectivity, dead ends, and undershoot detection).
* Added `walk_build_network()` with user-controlled snapping and planarization.
* Added `walk_compute_reach()` for 10-minute walkable network length calculations.
* Added `walk_compute_circuity()` for detour ratio evaluation.
* Added `walk_plot_reach()` and `walk_plot_diagnosis()` for publication-grade cartography using `ggplot2` and `viridis`.
* Added `walk_shortest_path()` with compiled Rust Dijkstra for single-pair routing, path geometry reconstruction, travel time, and detour circuity.
* Added `walk_isochrone()` for multi-threshold walkable polygon envelopes (concave hull and corridor buffers) and sub-network extraction.
* Added `walk_intersection_density()` for junction valence morphology (cul-de-sacs, T-junctions, crossroads) and intersection density per km².
* Added `walk_compute_access()` for multi-threaded cumulative accessibility to urban facilities/POIs (schools, clinics, transport) in parallel Rust.
* Added `walk_scenario_close()` and `walk_compare_scenarios()` for evaluating street pedestrianization and closure impacts.
* Added `as_sfnetwork()` and `as_tidygraph()` for seamless interoperability with the `sfnetworks` and `tidygraph` spatial network ecosystems.
