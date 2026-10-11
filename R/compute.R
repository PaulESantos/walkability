#' Compute Reachable Walkable Network Length Metric
#'
#' Computes the total walkable network length lying within each node's isochrone
#' (default 10-minute walk at 4.5 km/h, ~750 m budget). The calculation runs
#' in parallel using compiled Rust and applies the exact partial-edge credit rule,
#' crediting crossing frontier edges for only their reachable fraction.
#'
#' @param network A `walk_network` object produced by [walk_build_network()].
#' @param time_min Walking time budget in minutes (default is 10.0 minutes).
#'   Users can freely customize this parameter; for smaller neighborhoods, compact districts,
#'   or localized analyses, values like 5.0 or 7.5 minutes can be used.
#' @param cutoff_s Optional walking time budget in seconds (e.g. 600.0). If specified,
#'   it overrides `time_min`.
#' @param target Character string. Either `"largest_component"` (default) to compute
#'   only for nodes in the primary connected component, or `"all"`.
#' @param n_threads Number of CPU threads to use in parallel (0 = auto-detect all available cores).
#' @param verbose Logical. If `TRUE`, prints summary percentiles and runtime.
#'
#' @return A `walk_reach` S3 object containing:
#'   \item{nodes}{`sf` points table augmented with `reachable_length_m` and `reachable_length_km`.}
#'   \item{edges}{`sf` lines table augmented with `reachable_length_km` (mean of endpoints).}
#'   \item{summary}{Summary statistics (min, mean, max, 5th, 95th percentiles).}
#'   \item{time_min}{The time cutoff in minutes.}
#'   \item{cutoff_s}{The time cutoff in seconds.}
#'   \item{network}{The input `walk_network` object.}
#' @export
#'
#' @examples
#' \dontrun{
#' # Standard 10-minute walk reach
#' reach <- walk_compute_reach(net, time_min = 10)
#'
#' # Short 5-minute neighborhood reach
#' reach_5m <- walk_compute_reach(net, time_min = 5)
#' print(reach_5m)
#' plot(reach_5m)
#' }
walk_compute_reach <- function(network,
                               time_min = 10.0,
                               cutoff_s = NULL,
                               target = c("largest_component", "all"),
                               n_threads = 0,
                               verbose = TRUE) {
  target <- match.arg(target)

  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  # Resolve time cutoff in seconds
  if (!is.null(cutoff_s)) {
    if (cutoff_s <= 0) {
      cli::cli_abort("{.arg cutoff_s} must be strictly positive.")
    }
    actual_cutoff_s <- as.numeric(cutoff_s)
  } else {
    if (time_min <= 0) {
      cli::cli_abort("{.arg time_min} must be strictly positive.")
    }
    actual_cutoff_s <- as.numeric(time_min * 60.0)
  }

  csr <- network$csr
  n_nodes <- nrow(network$nodes)

  # Determine target nodes to compute
  if (target == "largest_component") {
    target_indices <- which(network$nodes$is_giant) - 1L
  } else {
    target_indices <- seq_len(n_nodes) - 1L
  }

  cutoff_min <- actual_cutoff_s / 60.0
  if (verbose) {
    cli::cli_alert_info("Computing reachable network length for {length(target_indices)} nodes ({sprintf('%.1f', cutoff_min)} min walk)...")
  }

  t0 <- Sys.time()
  
  # Call multi-threaded Rust kernel
  reach_vals <- rust_compute_reachable_length(
    n_nodes = as.integer(n_nodes),
    head_num = as.numeric(csr$head),
    to = as.integer(csr$to),
    wt = as.numeric(csr$wt),
    wl = as.numeric(csr$wl),
    target_nodes = as.integer(target_indices),
    cutoff = as.numeric(actual_cutoff_s),
    num_threads = as.integer(n_threads)
  )

  runtime_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (verbose) {
    cli::cli_alert_success("Finished Dijkstra computation in {sprintf('%.2f', runtime_s)} seconds.")
  }

  # Build complete per-node array
  node_reach_m <- rep(NA_real_, n_nodes)
  node_reach_m[target_indices + 1L] <- reach_vals
  node_reach_km <- node_reach_m / 1000.0

  # Augment nodes sf
  nodes_aug <- network$nodes
  nodes_aug$reachable_length_m <- node_reach_m
  nodes_aug$reachable_length_km <- node_reach_km

  # Augment edges sf with mean of its two endpoints' values
  edges_aug <- network$edges
  u_val <- node_reach_km[edges_aug$from_node + 1L]
  v_val <- node_reach_km[edges_aug$to_node + 1L]
  # Linear approximation along the segment
  edges_aug$reachable_length_km <- (u_val + v_val) / 2.0

  # Compute summary statistics on valid values
  valid_vals <- node_reach_km[!is.na(node_reach_km)]
  stats <- list(
    count = length(valid_vals),
    min_km = min(valid_vals, na.rm = TRUE),
    mean_km = mean(valid_vals, na.rm = TRUE),
    max_km = max(valid_vals, na.rm = TRUE),
    p05_km = stats::quantile(valid_vals, 0.05, na.rm = TRUE),
    p95_km = stats::quantile(valid_vals, 0.95, na.rm = TRUE),
    p02_km = stats::quantile(valid_vals, 0.02, na.rm = TRUE),
    p98_km = stats::quantile(valid_vals, 0.98, na.rm = TRUE)
  )

  res <- structure(
    list(
      nodes = nodes_aug,
      edges = edges_aug,
      summary = stats,
      time_min = actual_cutoff_s / 60.0,
      cutoff_s = actual_cutoff_s,
      runtime_s = runtime_s,
      network = network
    ),
    class = "walk_reach"
  )

  if (verbose) {
    print(res)
  }

  res
}

#' Print Method for Walk Reach Metric
#'
#' @param x A `walk_reach` object.
#' @param ... Additional arguments.
#' @export
print.walk_reach <- function(x, ...) {
  s <- x$summary
  time_m <- if (!is.null(x$time_min)) x$time_min else (x$cutoff_s / 60.0)
  speed_kmh <- x$network$walk_speed_kmh
  approx_dist_m <- round(x$cutoff_s * (speed_kmh / 3.6))

  cli::cli_h1("Walkability Reachable Network Length")
  cli::cli_bullets(c(
    "v" = paste0("Isochrone Budget: ", cli::col_blue(sprintf("%.1f minutes", time_m)), " (~", approx_dist_m, " m at ", speed_kmh, " km/h)"),
    "v" = paste0("Evaluated Nodes: ", cli::col_green(format(s$count, big.mark = ","))),
    "*" = paste0("Average Reach: ", cli::col_yellow(sprintf("%.2f km", s$mean_km))),
    "*" = paste0("Highest Reach: ", cli::col_green(sprintf("%.2f km", s$max_km))),
    "*" = paste0("Lowest Reach: ", cli::col_red(sprintf("%.2f km", s$min_km))),
    "*" = paste0("5th-95th percentile: ", sprintf("%.1f - %.1f km", s$p05_km, s$p95_km))
  ))
  invisible(x)
}

#' Plot Method for Walk Reach Object
#'
#' @param x A `walk_reach` object.
#' @param ... Additional arguments passed to [walk_plot_reach()].
#' @return A `ggplot` object.
#' @export
plot.walk_reach <- function(x, ...) {
  walk_plot_reach(x, ...)
}

#' Compute Network Circuity (Detour Ratio) for Sampled Junctions
#'
#' Evaluates path directness by comparing network shortest-path distances against
#' Euclidean straight-line distances. High circuity signifies indirect, circuitous
#' street patterns and cul-de-sacs.
#'
#' @param network A `walk_network` object.
#' @param sample_size Number of random junctions to sample. Default is 500.
#' @param time_min Walking time budget in minutes (default is 10.0 minutes).
#' @param cutoff_s Optional walking time budget in seconds (default is `NULL`).
#'   If provided, it overrides `time_min`.
#'
#' @return A `tibble` with node IDs and calculated detour ratios.
#' @export
walk_compute_circuity <- function(network, sample_size = 500, time_min = 10.0, cutoff_s = NULL) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  if (!is.null(cutoff_s)) {
    if (cutoff_s <= 0) {
      cli::cli_abort("{.arg cutoff_s} must be strictly positive.")
    }
    actual_cutoff_s <- as.numeric(cutoff_s)
  } else {
    if (time_min <= 0) {
      cli::cli_abort("{.arg time_min} must be strictly positive.")
    }
    actual_cutoff_s <- as.numeric(time_min * 60.0)
  }

  csr <- network$csr
  n_nodes <- nrow(network$nodes)
  giant_nodes <- which(network$nodes$is_giant) - 1L

  sample_n <- min(length(giant_nodes), sample_size)
  sample_nodes <- sample(giant_nodes, sample_n)

  # Extract coordinates
  coords <- sf::st_coordinates(network$nodes)

  res <- rust_compute_circuity_sample(
    n_nodes = as.integer(n_nodes),
    head_num = as.numeric(csr$head),
    to = as.integer(csr$to),
    wt = as.numeric(csr$wt),
    wl = as.numeric(csr$wl),
    coords_x = as.numeric(coords[, 1]),
    coords_y = as.numeric(coords[, 2]),
    sample_nodes = as.integer(sample_nodes),
    cutoff = as.numeric(actual_cutoff_s)
  )

  tibble::as_tibble(res)
}
