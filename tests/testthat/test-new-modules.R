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

test_that("walk_app components initialize properly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("mapgl")

  ui <- walkability:::.create_walk_app_ui()
  expect_s3_class(ui, "shiny.tag.list")

  server <- walkability:::.create_walk_app_server()
  expect_true(is.function(server))
})

