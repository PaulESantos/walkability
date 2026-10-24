#' Compute Shortest Pedestrian Path Between Two Locations
#'
#' Finds the optimal walking route between an origin and destination across the
#' street graph using Dijkstra's algorithm compiled in Rust. Supports node IDs,
#' numeric coordinate vectors `c(x, y)`, or `sf` point geometries.
#'
#' @param network A `walk_network` object created by [walk_build_network()].
#' @param from Origin location: either an integer node index, a numeric vector
#'   `c(x, y)` in the network's metric CRS, or an `sf` POINT.
#' @param to Destination location: either an integer node index, a numeric vector
#'   `c(x, y)` in the network's metric CRS, or an `sf` POINT.
#'
#' @return A `walk_path` S3 object containing:
#'   \item{path_sf}{`sf` object with the route geometry (`LINESTRING`) and attributes.}
#'   \item{nodes_sf}{`sf` points along the path in traversed order.}
#'   \item{node_ids}{Sequence of node IDs visited.}
#'   \item{distance_m}{Total walking route distance in meters.}
#'   \item{time_s}{Total travel time in seconds at the network walking speed.}
#'   \item{time_min}{Total travel time in minutes.}
#'   \item{circuity}{Detour ratio (network path distance / straight-line Euclidean distance).}
#'   \item{from_node}{Resolved origin node index.}
#'   \item{to_node}{Resolved destination node index.}
#'   \item{network}{The input `walk_network`.}
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' orig <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
#' dest <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[50, 1:2]
#' p <- walk_shortest_path(net, from = orig, to = dest)
#' print(p)
walk_shortest_path <- function(network, from, to) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  nodes <- network$nodes
  n_nodes <- nrow(nodes)
  csr <- network$csr

  # Helper to resolve input location to a node index (0-indexed)
  resolve_node <- function(loc, label) {
    if (is.numeric(loc) && length(loc) == 1) {
      idx <- as.integer(loc)
      # Check if given as 1-indexed R or 0-indexed node_id
      if (idx >= 0 && idx < n_nodes) {
        return(idx)
      } else if (idx == n_nodes) {
        return(idx - 1L)
      } else {
        cli::cli_abort("Node index for {.arg {label}} ({loc}) is out of bounds [0, {n_nodes - 1}].")
      }
    } else if (inherits(loc, "sf") || inherits(loc, "sfc") || (is.numeric(loc) && length(loc) == 2)) {
      coords <- if (is.numeric(loc)) c(loc[1], loc[2]) else sf::st_coordinates(sf::st_geometry(loc)[[1]])[1, 1:2]
      target_pt <- sf::st_sfc(sf::st_point(coords), crs = sf::st_crs(nodes))
      cand_nodes <- if (any(nodes$is_giant)) nodes[nodes$is_giant, ] else nodes
      nearest_row <- sf::st_nearest_feature(target_pt, cand_nodes)
      return(as.integer(cand_nodes$node_id[nearest_row]))
    } else {
      cli::cli_abort("Invalid format for {.arg {label}}. Expected node index, c(x, y), or sf POINT.")
    }
  }

  src_idx <- resolve_node(from, "from")
  dst_idx <- resolve_node(to, "to")

  res <- rust_shortest_path(
    n_nodes = as.integer(n_nodes),
    head_num = as.numeric(csr$head),
    to = as.integer(csr$to),
    wt = as.numeric(csr$wt),
    wl = as.numeric(csr$wl),
    src_node = as.integer(src_idx),
    dst_node = as.integer(dst_idx)
  )

  if (!isTRUE(res$found) || length(res$node_path) == 0) {
    cli::cli_abort("No path found between node {src_idx} and node {dst_idx}. They might reside in disconnected components.")
  }

  path_nodes_idx <- res$node_path + 1L # to 1-indexed R
  path_nodes_sf <- nodes[path_nodes_idx, ]

  # Build path LineString geometry from node coordinates
  node_coords <- sf::st_coordinates(path_nodes_sf)
  if (nrow(node_coords) == 1) {
    # Same origin and destination
    path_geom <- sf::st_sfc(sf::st_linestring(rbind(node_coords[1, 1:2], node_coords[1, 1:2])), crs = sf::st_crs(nodes))
  } else {
    path_geom <- sf::st_sfc(sf::st_linestring(node_coords[, 1:2]), crs = sf::st_crs(nodes))
  }

  # Euclidean distance
  src_c <- node_coords[1, 1:2]
  dst_c <- node_coords[nrow(node_coords), 1:2]
  euclid_dist <- sqrt(sum((dst_c - src_c)^2))

  circuity <- if (euclid_dist > 1.0) res$total_length_m / euclid_dist else 1.0

  path_sf <- sf::st_sf(
    from_node = src_idx,
    to_node = dst_idx,
    distance_m = res$total_length_m,
    time_s = res$total_time_s,
    time_min = res$total_time_s / 60.0,
    circuity = circuity,
    geometry = path_geom,
    crs = sf::st_crs(nodes)
  )

  out <- structure(
    list(
      path_sf = path_sf,
      nodes_sf = path_nodes_sf,
      node_ids = res$node_path,
      distance_m = res$total_length_m,
      time_s = res$total_time_s,
      time_min = res$total_time_s / 60.0,
      circuity = circuity,
      from_node = src_idx,
      to_node = dst_idx,
      network = network
    ),
    class = "walk_path"
  )

  out
}

#' Print Method for Walk Path
#'
#' @param x A `walk_path` object.
#' @param ... Additional arguments.
#' @return The `walk_path` object `x`, invisibly, after printing its summary.
#' @export
print.walk_path <- function(x, ...) {
  cli::cli_h1("Walkability Shortest Path")
  cli::cli_bullets(c(
    "v" = paste0("Origin Node: ", cli::col_blue(x$from_node), " -> Destination Node: ", cli::col_blue(x$to_node)),
    "v" = paste0("Nodes Visited: ", cli::col_green(length(x$node_ids))),
    "*" = paste0("Walking Distance: ", cli::col_yellow(sprintf("%.1f m (%.2f km)", x$distance_m, x$distance_m / 1000))),
    "*" = paste0("Estimated Time: ", cli::col_cyan(sprintf("%.1f min (%.0f s)", x$time_min, x$time_s))),
    "*" = paste0("Route Circuity: ", cli::col_magenta(sprintf("%.3f", x$circuity)))
  ))
  invisible(x)
}

#' Plot Method for Walk Path
#'
#' Visualizes the shortest pedestrian path overlaid on the local street network.
#'
#' @param x A `walk_path` object.
#' @param network Optional background `walk_network`. If `NULL`, uses the embedded network.
#' @param ... Additional arguments.
#' @return A `ggplot` object.
#' @export
plot.walk_path <- function(x, network = NULL, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  net <- if (!is.null(network)) network else x$network

  p <- ggplot2::ggplot()

  if (!is.null(net) && inherits(net, "walk_network")) {
    p <- p + ggplot2::geom_sf(data = net$edges, color = "#B0BEC5", linewidth = 0.5, alpha = 0.6)
  }

  p <- p +
    ggplot2::geom_sf(data = x$path_sf, color = "#E63946", linewidth = 1.6, lineend = "round") +
    ggplot2::geom_sf(data = x$nodes_sf[c(1, nrow(x$nodes_sf)), ], ggplot2::aes(color = factor(c("Origin", "Destination"))), size = 3.5) +
    ggplot2::scale_color_manual(
      name = "Location",
      values = c("Origin" = "#2A9D8F", "Destination" = "#E76F51")
    ) +
    theme_walkability() +
    ggplot2::labs(
      title = "Optimal Pedestrian Route",
      subtitle = sprintf("Distance: %.1f m | Travel Time: %.1f min | Circuity: %.2f", x$distance_m, x$time_min, x$circuity)
    )

  p
}
