test_that("Rust CSR builder collapses parallel edges and drops self-loops", {
  n_nodes <- 3L
  u <- c(0L, 0L, 1L, 2L)
  v <- c(1L, 1L, 2L, 2L) # includes parallel edge (0,1) and self loop (2,2)
  wt <- c(10.0, 5.0, 8.0, 1.0)
  wl <- c(100.0, 50.0, 80.0, 10.0)

  csr <- rust_build_csr(n_nodes, u, v, wt, wl)

  expect_equal(csr$n_edges_collapsed, 2L)
  expect_equal(csr$giant_comp_size, 3L)
  expect_equal(csr$total_components, 1L)
})

test_that("Rust Dijkstra reachable length matches exact partial-edge calculation", {
  # 2-node single edge (dead end)
  # Length 1000m, time 800s. Cutoff 600s:
  # Expected reached length = 1000 * (600 / 800) = 750m
  n_nodes <- 2L
  u <- c(0L)
  v <- c(1L)
  wt <- c(800.0)
  wl <- c(1000.0)

  csr <- rust_build_csr(n_nodes, u, v, wt, wl)
  reach <- rust_compute_reachable_length(
    n_nodes = n_nodes,
    head_num = as.numeric(csr$head),
    to = as.integer(csr$to),
    wt = as.numeric(csr$wt),
    wl = as.numeric(csr$wl),
    target_nodes = c(0L, 1L),
    cutoff = 600.0,
    num_threads = 1L
  )

  expect_equal(reach[1], 750.0, tolerance = 1e-6)
  expect_equal(reach[2], 750.0, tolerance = 1e-6)

  # 3-node path: (0, 1) and (1, 2), each length 500m, time 400s.
  # From 0: reaches (0,1) in 400s (rem 200s), penetrates (1,2) for 200/400 = 0.5.
  # Total from 0 = 500 + 250 = 750m.
  # From 1 (middle): reaches (0,1) fully (400 <= 600) and (1,2) fully (400 <= 600).
  # Total from 1 = 500 + 500 = 1000m.
  n_nodes_3 <- 3L
  u_3 <- c(0L, 1L)
  v_3 <- c(1L, 2L)
  wt_3 <- c(400.0, 400.0)
  wl_3 <- c(500.0, 500.0)

  csr_3 <- rust_build_csr(n_nodes_3, u_3, v_3, wt_3, wl_3)
  reach_3 <- rust_compute_reachable_length(
    n_nodes = n_nodes_3,
    head_num = as.numeric(csr_3$head),
    to = as.integer(csr_3$to),
    wt = as.numeric(csr_3$wt),
    wl = as.numeric(csr_3$wl),
    target_nodes = c(0L, 1L, 2L),
    cutoff = 600.0,
    num_threads = 1L
  )

  expect_equal(reach_3[1], 750.0, tolerance = 1e-6)
  expect_equal(reach_3[2], 1000.0, tolerance = 1e-6)
  expect_equal(reach_3[3], 750.0, tolerance = 1e-6)
})

test_that("End-to-end walk_build_network and walk_compute_reach work on synthetic sf data", {
  # Create a simple synthetic 2x2 grid in UTM meters
  coords_list <- list(
    matrix(c(0, 0, 100, 0), ncol = 2, byrow = TRUE),
    matrix(c(100, 0, 100, 100), ncol = 2, byrow = TRUE),
    matrix(c(100, 100, 0, 100), ncol = 2, byrow = TRUE),
    matrix(c(0, 100, 0, 0), ncol = 2, byrow = TRUE),
    matrix(c(0, 0, 100, 100), ncol = 2, byrow = TRUE) # diagonal
  )
  lines <- sf::st_sfc(lapply(coords_list, sf::st_linestring), crs = 32722)
  df <- sf::st_as_sf(data.frame(id = 1:5), geometry = lines)

  # Diagnose
  diag <- walk_diagnose_network(df, snap_search_radius_m = 5)
  expect_s3_class(diag, "walk_diagnosis")
  expect_equal(diag$total_components, 1L)

  # Build network
  net <- walk_build_network(df, walk_speed_kmh = 4.5, verbose = FALSE)
  expect_s3_class(net, "walk_network")
  expect_equal(nrow(net$nodes), 4L)

  # Compute reach
  reach <- walk_compute_reach(net, cutoff_s = 600.0, verbose = FALSE)
  expect_s3_class(reach, "walk_reach")
  expect_true(all(!is.na(reach$nodes$reachable_length_km)))
  expect_gt(reach$summary$mean_km, 0)

  # Plot reach
  p <- walk_plot_reach(reach)
  expect_s3_class(p, "ggplot")
})
