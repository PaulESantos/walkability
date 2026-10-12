test_that("Model datasets load correctly and have valid CRS", {
  data("streets_cusco", package = "walkability", envir = environment())
  data("streets_lima", package = "walkability", envir = environment())
  data("streets_arequipa", package = "walkability", envir = environment())

  expect_s3_class(streets_cusco, "sf")
  expect_s3_class(streets_lima, "sf")
  expect_s3_class(streets_arequipa, "sf")

  expect_equal(sf::st_crs(streets_cusco)$epsg, 32719L)
  expect_equal(sf::st_crs(streets_lima)$epsg, 32718L)
  expect_equal(sf::st_crs(streets_arequipa)$epsg, 32719L)

  expect_gt(nrow(streets_cusco), 400L)
  expect_gt(nrow(streets_lima), 800L)
  expect_gt(nrow(streets_arequipa), 400L)
})

test_that("GeoPackages in inst/extdata are accessible and readable", {
  gpkg_cusco <- system.file("extdata", "cusco_streets.gpkg", package = "walkability")
  gpkg_lima <- system.file("extdata", "lima_streets.gpkg", package = "walkability")
  gpkg_arequipa <- system.file("extdata", "arequipa_streets.gpkg", package = "walkability")

  expect_true(file.exists(gpkg_cusco))
  expect_true(file.exists(gpkg_lima))
  expect_true(file.exists(gpkg_arequipa))

  lines_c <- sf::st_read(gpkg_cusco, quiet = TRUE)
  expect_gt(nrow(lines_c), 0L)
})

test_that("End-to-end network build, reach, and shortest path on real Cusco OSM dataset", {
  data("streets_cusco", package = "walkability", envir = environment())
  net_cusco <- walk_build_network(streets_cusco, verbose = FALSE)

  expect_s3_class(net_cusco, "walk_network")
  expect_gt(nrow(net_cusco$nodes), 100L)

  # Compute 5-min walk reach on giant component
  reach_cusco <- walk_compute_reach(net_cusco, time_min = 5.0, verbose = FALSE)
  expect_s3_class(reach_cusco, "walk_reach")
  expect_gt(reach_cusco$summary$mean_km, 0.5)

  # Compute shortest path between two nodes in the giant component
  giant_nodes <- which(net_cusco$nodes$is_giant) - 1L
  n1 <- giant_nodes[1]
  n2 <- giant_nodes[20]

  path_cusco <- walk_shortest_path(net_cusco, from = n1, to = n2)
  expect_s3_class(path_cusco, "walk_path")
  expect_gt(path_cusco$distance_m, 0.0)
})
