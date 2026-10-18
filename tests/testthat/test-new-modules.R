test_that("walk_shortest_path computes exact route on synthetic network", {
  # Synthetic 2x2 grid
  coords_list <- list(
    matrix(c(0, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(100, 0, 100, 100), ncol = 2, byrow = TRUE),
    matrix(c(100, 100, 0, 100), ncol = 2, byrow = TRUE),
    matrix(c(0, 100, 0, 0), ncol = 2, byrow = TRUE)
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  streets <- sf::st_as_sf(data.frame(id = 1:4), geometry = lines)
  net <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)

  # Route from node (0,0) to node (100,100)
  path <- walk_shortest_path(net, from = c(0, 0), to = c(100, 100))
  expect_s3_class(path, "walk_path")
  expect_equal(path$distance_m, 200.0)
  expect_equal(path$time_s, 200.0 / (4.5 / 3.6), tolerance = 1e-4)
  expect_gt(path$circuity, 1.0)
  expect_equal(length(path$node_ids), 3L)

  # Same node
  path_self <- walk_shortest_path(net, from = c(0, 0), to = c(0, 0))
  expect_equal(path_self$distance_m, 0.0)
  expect_equal(path_self$circuity, 1.0)

  # Plot method
  p <- plot(path)
  expect_s3_class(p, "ggplot")
})

test_that("walk_isochrone creates valid polygons and reachable corridors", {
  coords_list <- list(
    matrix(c(0, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(100, 0, 100, 100), ncol = 2, byrow = TRUE),
    matrix(c(100, 100, 0, 100), ncol = 2, byrow = TRUE),
    matrix(c(0, 100, 0, 0), ncol = 2, byrow = TRUE)
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  streets <- sf::st_as_sf(data.frame(id = 1:4), geometry = lines)
  net <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)

  iso <- walk_isochrone(net, origin = c(0, 0), time_min = c(5, 10), method = "buffer", buffer_m = 20, rings = FALSE)
  expect_s3_class(iso, "walk_isochrone")
  expect_equal(nrow(iso$polygons), 2L)
  expect_true(all(iso$polygons$area_km2 > 0))
  expect_true(all(iso$polygons$network_length_km > 0))

  p <- plot(iso)
  expect_s3_class(p, "ggplot")
})

test_that("walk_intersection_density classifies cul-de-sacs and intersections correctly", {
  # T-junction network: (0,0)-(100,0) and (50,0)-(50,50)
  coords_list <- list(
    matrix(c(0, 0, 50, 0), ncol = 2, byrow = TRUE),
    matrix(c(50, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(50, 0, 50, 50), ncol = 2, byrow = TRUE)
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  streets <- sf::st_as_sf(data.frame(id = 1:3), geometry = lines)
  net <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)

  morph <- walk_intersection_density(net)
  expect_s3_class(morph, "walk_morphology")
  # 3 dead ends (cul-de-sacs) at (0,0), (100,0), (50,50)
  expect_equal(morph$summary$cul_de_sacs, 3L)
  # 1 3-way intersection at (50,0)
  expect_equal(morph$summary$three_way_junctions, 1L)
  expect_equal(morph$summary$intersections, 1L)
  expect_gt(morph$summary$mean_node_degree, 1.0)

  p <- plot(morph)
  expect_s3_class(p, "ggplot")
})

test_that("walk_compute_access evaluates multi-facility accessibility", {
  coords_list <- list(
    matrix(c(0, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(100, 0, 100, 100), ncol = 2, byrow = TRUE),
    matrix(c(100, 100, 0, 100), ncol = 2, byrow = TRUE),
    matrix(c(0, 100, 0, 0), ncol = 2, byrow = TRUE)
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  streets <- sf::st_as_sf(data.frame(id = 1:4), geometry = lines)
  net <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)

  # Synthetic POIs: 1 school at (100, 100) and 1 clinic at (0, 100)
  poi_pts <- sf::st_sfc(
    sf::st_point(c(100, 100)),
    sf::st_point(c(0, 100)),
    crs = 32722
  )
  pois <- sf::st_sf(
    amenity = c("school", "clinic"),
    geometry = poi_pts
  )

  acc <- walk_compute_access(net, pois = pois, time_min = 10, category_col = "amenity", verbose = FALSE)
  expect_s3_class(acc, "walk_access")
  expect_true("access_school_count" %in% names(acc$nodes))
  expect_true("access_clinic_count" %in% names(acc$nodes))

  # Every node can reach both facilities in 10 minutes (network is 400m perimeter, 10 min = 750m)
  expect_true(all(acc$nodes$access_school_count == 1.0))
  expect_true(all(acc$nodes$access_clinic_count == 1.0))

  p <- plot(acc, category = "school")
  expect_s3_class(p, "ggplot")
})

test_that("walk_scenario_close and walk_compare_scenarios model street pedestrianization", {
  coords_list <- list(
    matrix(c(0, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(100, 0, 100, 100), ncol = 2, byrow = TRUE),
    matrix(c(100, 100, 0, 100), ncol = 2, byrow = TRUE),
    matrix(c(0, 100, 0, 0), ncol = 2, byrow = TRUE)
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  streets <- sf::st_as_sf(data.frame(id = 1:4), geometry = lines)
  net <- walk_build_network(streets, walk_speed_kmh = 4.5, verbose = FALSE)

  # Close edge 1
  cierre <- walk_scenario_close(net, edge_indices = 1L, name = "Cierre de calle 1")
  expect_s3_class(cierre, "walk_scenario")
  expect_equal(nrow(cierre$edges), 3L)
  expect_equal(nrow(cierre$closed_edges), 1L)

  # Compare base vs scenario
  comp <- walk_compare_scenarios(base = net, scenario = cierre, time_min = 5.0, verbose = FALSE)
  expect_s3_class(comp, "walk_comparison")
  expect_equal(comp$summary$Delta[1], -1) # 1 less edge
  expect_equal(comp$summary$Delta[2], -0.1) # 100m less

  p <- plot(comp)
  expect_s3_class(p, "ggplot")
})

test_that("walk_isochrone creates non-overlapping concentric rings with rings = TRUE", {
  data(streets_cusco)
  net <- walk_build_network(streets_cusco, verbose = FALSE)
  center <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]

  iso <- walk_isochrone(net, origin = center, time_min = c(5, 10), rings = TRUE)
  expect_s3_class(iso, "walk_isochrone")
  expect_equal(nrow(iso$polygons), 2L)
  expect_true(isTRUE(iso$rings))
  expect_true("interval" %in% names(iso$polygons))
  expect_true(!is.null(iso$cumulative_polygons))

  # Test topological non-overlap: intersection area between rings should be ~0
  inter <- sf::st_intersection(iso$polygons$geometry[1], iso$polygons$geometry[2])
  expect_lt(as.numeric(sf::st_area(inter)), 1e-3)
})

test_that("walk_app components initialize properly in Spanish and English", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("mapgl")

  # 1. Default Spanish UI
  ui_es <- walkability:::.create_walk_app_ui(initial_lang = "es")
  expect_s3_class(ui_es, "shiny.tag.list")
  ui_es_str <- as.character(ui_es)

  expect_true(grepl("app_lang", ui_es_str))
  expect_true(grepl("dl_reach_sf", ui_es_str))
  expect_true(grepl("dl_iso_sf", ui_es_str))
  expect_true(grepl("dl_route_sf", ui_es_str))
  expect_true(grepl("dl_morph_sf", ui_es_str))
  expect_true(grepl("dl_scen_sf", ui_es_str))
  expect_true(grepl("dl_betweenness_base_sf", ui_es_str))
  expect_true(grepl("dl_betweenness_sim_sf", ui_es_str))
  expect_true(grepl("scen_view_mode", ui_es_str))
  expect_true(grepl("scen_snap_radius", ui_es_str))
  expect_true(grepl("Intermediaci.n: qu. mide", ui_es_str))
  expect_true(grepl("Alcance Peatonal", ui_es_str))
  expect_true(grepl("code_text_display", ui_es_str))

  # 2. English UI
  ui_en <- walkability:::.create_walk_app_ui(initial_lang = "en")
  expect_s3_class(ui_en, "shiny.tag.list")
  ui_en_str <- as.character(ui_en)

  expect_true(grepl("app_lang", ui_en_str))
  expect_true(grepl("Pedestrian Reach", ui_en_str))
  expect_true(grepl("Select Street Network:", ui_en_str))
  expect_true(grepl("Betweenness: What it Measures", ui_en_str))
  expect_true(grepl("Download Active Network", ui_en_str))

  # 3. Server functions
  server_es <- walkability:::.create_walk_app_server(initial_lang = "es")
  expect_true(is.function(server_es))

  server_en <- walkability:::.create_walk_app_server(initial_lang = "en")
  expect_true(is.function(server_en))

  utils::data(streets_cusco)
  net_test <- walk_build_network(streets_cusco, verbose = FALSE)
  srv_inst <- walkability:::.create_walk_app_server(net_test, initial_lang = "es")
  shiny::testServer(srv_inst, {
    session$flushReact()
    expect_match(output$reach_stat_mean, "^[0-9]+(\\.[0-9]+)?\\s*km$")
    expect_match(output$reach_stat_max, "^[0-9]+(\\.[0-9]+)?\\s*km$")
  })

  # 4. Helper dictionary
  expect_equal(walkability:::.app_i18n("tab_reach", "es"), "\U0001f6b6 Alcance Peatonal (Reach)")
  expect_equal(walkability:::.app_i18n("tab_reach", "en"), "\U0001f6b6 Pedestrian Reach")
})

test_that("walk_betweenness calculates edge centrality and respects parameters", {
  skip_if_not_installed("igraph")
  utils::data(streets_cusco)
  net <- walk_build_network(streets_cusco, verbose = FALSE)

  bw <- walk_betweenness(net)
  expect_s3_class(bw, "walk_betweenness")
  expect_true("betweenness" %in% names(bw$edges))
  expect_true("betweenness_norm" %in% names(bw$edges))
  expect_true("betweenness_pctl" %in% names(bw$edges))
  expect_true("bottleneck_class" %in% names(bw$edges))
  expect_gt(bw$summary$max_betweenness, 0)
  expect_equal(nrow(bw$edges), nrow(net$edges))

  # Test with search radius cutoff
  bw_cut <- walk_betweenness(net, radius_m = 500)
  expect_s3_class(bw_cut, "walk_betweenness")
  expect_true(bw_cut$summary$radius_m == 500)

  # Test with snap tolerance
  bw_snap <- walk_betweenness(net, snap_tolerance_m = 5.0)
  expect_s3_class(bw_snap, "walk_betweenness")
  expect_equal(bw_snap$summary$snap_tolerance_m, 5.0)
})

test_that("walk_scenario_betweenness evaluates closures and identifies diverted streets", {
  skip_if_not_installed("igraph")
  utils::data(streets_cusco)
  net <- walk_build_network(streets_cusco, verbose = FALSE)

  sim <- walk_scenario_betweenness(net, closed_edges = c(5, 10), verbose = FALSE)
  expect_s3_class(sim, "walk_scenario_betweenness")
  expect_equal(sim$summary$n_closed, 2)
  expect_true("delta_betweenness" %in% names(sim$edges))
  expect_true("is_closed" %in% names(sim$edges))
  expect_true(all(sim$edges$is_closed[c(5, 10)]))
  expect_equal(sim$edges$betweenness_sim[5], 0)
  expect_equal(sim$edges$betweenness_sim[10], 0)

  # Top diverted streets table
  expect_true(is.data.frame(sim$top_diverted))
  expect_gt(nrow(sim$top_diverted), 0)
  expect_true("Incremento (Delta)" %in% names(sim$top_diverted))
})

test_that("walk_build_network with crs = 'auto' automatically projects geographic WGS84 data", {
  utils::data(streets_cusco)
  cusco_wgs84 <- sf::st_transform(streets_cusco, 4326)
  expect_true(sf::st_is_longlat(cusco_wgs84))

  # crs = 'auto' should project to metric UTM without error
  net_auto <- walk_build_network(cusco_wgs84, crs = "auto", repair = FALSE, verbose = FALSE)
  expect_s3_class(net_auto, "walk_network")
  expect_false(sf::st_is_longlat(net_auto$nodes))
  expect_equal(sf::st_crs(net_auto$nodes)$epsg, 32719)
})

test_that(".load_spatial_network_from_upload properly parses zipped shapefiles and geopackages", {
  utils::data(streets_cusco)
  cusco_wgs84 <- sf::st_transform(streets_cusco, 4326)

  # 1. Test GeoPackage in WGS84
  tmp_gpkg <- tempfile(fileext = ".gpkg")
  sf::st_write(cusco_wgs84, tmp_gpkg, quiet = TRUE)
  df_gpkg <- data.frame(
    name = basename(tmp_gpkg),
    size = file.size(tmp_gpkg),
    type = "application/geopackage+sqlite3",
    datapath = tmp_gpkg,
    stringsAsFactors = FALSE
  )
  res_gpkg <- walkability:::.load_spatial_network_from_upload(df_gpkg)
  expect_s3_class(res_gpkg$network, "walk_network")
  expect_equal(res_gpkg$format, "GeoPackage (.gpkg)")
  expect_false(sf::st_is_longlat(res_gpkg$network$nodes))

  # 2. Test Zipped Shapefile in WGS84
  tmp_shp_dir <- tempfile(pattern = "shp_test_")
  dir.create(tmp_shp_dir)
  sf::st_write(cusco_wgs84, file.path(tmp_shp_dir, "tramos.shp"), quiet = TRUE)
  tmp_zip <- tempfile(fileext = ".zip")
  old_wd <- setwd(tmp_shp_dir)
  utils::zip(tmp_zip, files = list.files(tmp_shp_dir))
  setwd(old_wd)

  df_zip <- data.frame(
    name = "tramos_red.zip",
    size = file.size(tmp_zip),
    type = "application/zip",
    datapath = tmp_zip,
    stringsAsFactors = FALSE
  )
  res_zip <- walkability:::.load_spatial_network_from_upload(df_zip)
  expect_s3_class(res_zip$network, "walk_network")
  expect_equal(res_zip$format, "Shapefile (.shp)")
  expect_false(sf::st_is_longlat(res_zip$network$nodes))

  # 3. Test repair with planarize and snap parameters forwarded
  res_repaired <- walkability:::.load_spatial_network_from_upload(
    df_gpkg,
    repair = TRUE,
    planarize = TRUE,
    snap_tolerance_m = 2.0
  )
  expect_s3_class(res_repaired$network, "walk_network")
  expect_true(res_repaired$planarize)
  expect_equal(res_repaired$snap_tolerance_m, 2.0)
})



