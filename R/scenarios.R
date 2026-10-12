#' Simulate Street Closure or Pedestrianization Intervention Scenario
#'
#' Creates an independent copy of a walkable street network with specified street
#' segments (edges) or junctions (nodes) removed (simulating street cuts, construction,
#' or pedestrianization). Reconstructs Compressed Sparse Row topology and component
#' connectivity using compiled Rust.
#'
#' @param network A `walk_network` object produced by [walk_build_network()].
#' @param edge_indices Integer vector of edge row indices to remove (1-indexed).
#' @param node_indices Optional integer vector of node indices whose attached edges will be removed.
#' @param name Descriptive character label for this intervention scenario.
#'
#' @return A new `walk_network` S3 object representing the modified scenario, with
#'   metadata storing the closed edges.
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' cierre <- walk_scenario_close(net, edge_indices = c(5, 12), name = "Peatonalizacion Central")
#' print(cierre)
walk_scenario_close <- function(network,
                                edge_indices = NULL,
                                node_indices = NULL,
                                name = "scenario_closure") {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  edges <- network$edges
  nodes <- network$nodes
  n_edges <- nrow(edges)
  n_nodes <- nrow(nodes)

  remove_mask <- rep(FALSE, n_edges)

  if (!is.null(edge_indices)) {
    valid_e <- edge_indices[edge_indices >= 1L & edge_indices <= n_edges]
    remove_mask[valid_e] <- TRUE
  }

  if (!is.null(node_indices)) {
    # 0-indexed or 1-indexed? Convert to 0-indexed
    target_nodes <- if (max(node_indices) >= n_nodes) node_indices - 1L else node_indices
    connected_mask <- (edges$from_node %in% target_nodes) | (edges$to_node %in% target_nodes)
    remove_mask <- remove_mask | connected_mask
  }

  if (!any(remove_mask)) {
    cli::cli_alert_warning("No valid edges selected for closure. Returning unaltered network.")
    return(network)
  }

  closed_edges <- edges[remove_mask, ]
  remaining_edges <- edges[!remove_mask, ]

  if (nrow(remaining_edges) == 0) {
    cli::cli_abort("Closure eliminated all edges in the network.")
  }

  # Re-index remaining edges and build updated CSR
  u <- remaining_edges$from_node
  v <- remaining_edges$to_node
  lengths_m <- remaining_edges$length_m
  travel_times_s <- remaining_edges$travel_time_s

  csr_new <- rust_build_csr(
    n_nodes = as.integer(n_nodes),
    u = as.integer(u),
    v = as.integer(v),
    wt = as.numeric(travel_times_s),
    wl = as.numeric(lengths_m)
  )

  # Update node component status
  nodes_updated <- nodes
  nodes_updated$component <- csr_new$comp
  nodes_updated$is_giant <- (csr_new$comp == csr_new$giant_comp_id)

  remaining_edges$is_giant <- (csr_new$comp[u + 1L] == csr_new$giant_comp_id) &
                              (csr_new$comp[v + 1L] == csr_new$giant_comp_id)

  res <- structure(
    list(
      nodes = nodes_updated,
      edges = remaining_edges,
      csr = csr_new,
      walk_speed_kmh = network$walk_speed_kmh,
      speed_ms = network$speed_ms,
      giant_comp_id = csr_new$giant_comp_id,
      giant_size = csr_new$giant_comp_size,
      total_components = csr_new$total_components,
      crs = network$crs,
      scenario_name = name,
      closed_edges = closed_edges
    ),
    class = c("walk_scenario", "walk_network")
  )

  res
}

#' Compare Baseline and Intervention Scenarios
#'
#' Compares structural topology and reachable walkable network length between
#' a baseline street network and an intervention scenario (e.g. street closures).
#'
#' @param base Baseline `walk_network` object.
#' @param scenario Modified `walk_network` (or `walk_scenario`) object.
#' @param time_min Walking budget in minutes for reach comparison (default 10.0 min).
#' @param verbose Logical. If `TRUE`, prints comparison summary.
#'
#' @return A `walk_comparison` S3 object.
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' cierre <- walk_scenario_close(net, edge_indices = c(5, 12), name = "Peatonalizacion Central")
#' comp <- walk_compare_scenarios(base = net, scenario = cierre, time_min = 5, verbose = FALSE)
#' print(comp)
walk_compare_scenarios <- function(base, scenario, time_min = 10.0, verbose = TRUE) {
  if (!inherits(base, "walk_network") || !inherits(scenario, "walk_network")) {
    cli::cli_abort("Both {.arg base} and {.arg scenario} must be {.cls walk_network} objects.")
  }

  # Compute reach for both
  if (verbose) {
    cli::cli_alert_info("Evaluating pedestrian reach for baseline network...")
  }
  reach_base <- walk_compute_reach(base, time_min = time_min, verbose = FALSE)

  if (verbose) {
    cli::cli_alert_info("Evaluating pedestrian reach for intervention scenario...")
  }
  reach_scen <- walk_compute_reach(scenario, time_min = time_min, verbose = FALSE)

  base_len_km <- sum(base$edges$length_m) / 1000.0
  scen_len_km <- sum(scenario$edges$length_m) / 1000.0

  diff_stats <- data.frame(
    Metric = c(
      "Total Edges",
      "Network Length (km)",
      "Giant Component Nodes",
      "Total Connected Components",
      "Mean Reach (km)",
      "Max Reach (km)"
    ),
    Base = c(
      nrow(base$edges),
      round(base_len_km, 2),
      base$giant_size,
      base$total_components,
      round(reach_base$summary$mean_km, 2),
      round(reach_base$summary$max_km, 2)
    ),
    Scenario = c(
      nrow(scenario$edges),
      round(scen_len_km, 2),
      scenario$giant_size,
      scenario$total_components,
      round(reach_scen$summary$mean_km, 2),
      round(reach_scen$summary$max_km, 2)
    ),
    stringsAsFactors = FALSE
  )
  diff_stats$Delta <- diff_stats$Scenario - diff_stats$Base

  # Delta reach per node
  delta_reach_km <- reach_scen$nodes$reachable_length_km - reach_base$nodes$reachable_length_km
  nodes_delta <- base$nodes
  nodes_delta$delta_reach_km <- delta_reach_km

  out <- structure(
    list(
      summary = diff_stats,
      reach_base = reach_base,
      reach_scenario = reach_scen,
      nodes_delta = nodes_delta,
      base = base,
      scenario = scenario,
      time_min = time_min
    ),
    class = "walk_comparison"
  )

  if (verbose) {
    print(out)
  }

  out
}

#' Print Method for Walk Comparison
#'
#' @param x A `walk_comparison` object.
#' @param ... Additional arguments.
#' @export
print.walk_comparison <- function(x, ...) {
  cli::cli_h1("Walkability Scenario Comparison")
  cli::cli_alert_info("Evaluation budget: {x$time_min} minutes at {x$base$walk_speed_kmh} km/h")
  print(x$summary, row.names = FALSE)
  invisible(x)
}

#' Plot Method for Walk Comparison
#'
#' Visualizes the closed streets in red alongside the difference in reachable pedestrian length.
#'
#' @param x A `walk_comparison` object.
#' @param ... Additional arguments.
#' @return A `ggplot` object.
#' @export
plot.walk_comparison <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  closed_edges <- x$scenario$closed_edges

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = x$scenario$edges, color = "#B0BEC5", linewidth = 0.5, alpha = 0.6)

  if (!is.null(closed_edges) && nrow(closed_edges) > 0) {
    p <- p + ggplot2::geom_sf(data = closed_edges, color = "#E63946", linewidth = 1.8)
  }

  p <- p +
    ggplot2::geom_sf(
      data = x$nodes_delta[!is.na(x$nodes_delta$delta_reach_km), ],
      ggplot2::aes(color = .data$delta_reach_km),
      size = 1.8
    ) +
    ggplot2::scale_color_gradient2(
      name = "\u0394 Reach (km)",
      low = "#D90429",
      mid = "#F8F9FA",
      high = "#2A9D8F",
      midpoint = 0
    ) +
    theme_walkability() +
    ggplot2::labs(
      title = "Scenario Impact on Pedestrian Walkability",
      subtitle = "Red lines mark closed streets; nodes indicate loss or gain in 10-min reach"
    )

  p
}
