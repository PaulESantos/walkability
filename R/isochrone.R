#' Compute Pedestrian Isochrone Polygons and Reachable Subgraphs
#'
#' Generates spatial polygon isochrones (concave hulls or buffered envelopes)
#' and extracts the exact reachable street network from an origin location for
#' specified walking time budgets (e.g. 5, 10, 15 minutes).
#'
#' @param network A `walk_network` object produced by [walk_build_network()].
#' @param origin Origin location: an integer node ID, coordinate vector `c(x, y)`,
#'   or an `sf` POINT.
#' @param time_min Numeric vector of walking time thresholds in minutes
#'   (e.g. `c(5, 10, 15)` or `10.0`).
#' @param method Polygon generation technique: `"concave"` for concave hull
#'   envelopes or `"buffer"` for street network buffering.
#' @param buffer_m Buffer width in meters applied along reachable edges when
#'   synthesizing pedestrian walkable corridors (default 25.0 m).
#' @param concave_ratio Ratio parameter passed to [sf::st_concave_hull()] (0 to 1, default 0.3).
#' @param rings Logical. If `TRUE` (default), multi-threshold polygons are transformed
#'   into mutually disjoint, non-overlapping concentric rings (e.g. 0-5 min, 5-10 min, 10-15 min)
#'   via topological differences, avoiding polygon occlusion. Cumulative envelopes are
#'   still preserved in the `cumulative_polygons` element.
#'
#' @return A `walk_isochrone` S3 object containing:
#'   \item{polygons}{`sf` polygons representing the isochrones (rings or cumulative).}
#'   \item{cumulative_polygons}{`sf` polygons with full cumulative envelopes.}
#'   \item{edges}{`sf` lines of all reached street segments with travel time.}
#'   \item{origin}{`sf` point of the resolved origin node.}
#'   \item{time_min}{The evaluated time thresholds.}
#'   \item{rings}{Logical indicating whether disjoint rings were generated.}
#'   \item{network}{The input `walk_network`.}
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' orig <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
#' iso <- walk_isochrone(net, origin = orig, time_min = c(5, 10), rings = TRUE)
#' print(iso)
walk_isochrone <- function(network,
                           origin,
                           time_min = c(5.0, 10.0, 15.0),
                           method = c("concave", "buffer"),
                           buffer_m = 25.0,
                           concave_ratio = 0.3,
                           rings = TRUE) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  method <- match.arg(method)
  nodes <- network$nodes
  n_nodes <- nrow(nodes)
  csr <- network$csr

  # Resolve origin
  if (is.numeric(origin) && length(origin) == 1) {
    src_idx <- as.integer(origin)
    if (src_idx < 0 || src_idx >= n_nodes) {
      if (src_idx == n_nodes) {
        src_idx <- src_idx - 1L
      } else {
        cli::cli_abort("Origin node index ({origin}) is out of bounds [0, {n_nodes - 1}].")
      }
    }
  } else if (inherits(origin, "sf") || inherits(origin, "sfc") || (is.numeric(origin) && length(origin) == 2)) {
    coords <- if (is.numeric(origin)) c(origin[1], origin[2]) else sf::st_coordinates(sf::st_geometry(origin)[[1]])[1, 1:2]
    target_pt <- sf::st_sfc(sf::st_point(coords), crs = sf::st_crs(nodes))
    cand_nodes <- if (any(nodes$is_giant)) nodes[nodes$is_giant, ] else nodes
    nearest_row <- sf::st_nearest_feature(target_pt, cand_nodes)
    src_idx <- as.integer(cand_nodes$node_id[nearest_row])
  } else {
    cli::cli_abort("Invalid format for {.arg origin}. Expected node index, c(x, y), or sf POINT.")
  }

  origin_sf <- nodes[src_idx + 1L, ]

  # Order time thresholds ascending
  cutoffs <- sort(as.numeric(time_min), decreasing = FALSE)

  poly_list <- list()
  edge_list <- list()

  for (t_min in cutoffs) {
    cutoff_s <- t_min * 60.0

    res <- rust_isochrone_subgraph(
      n_nodes = as.integer(n_nodes),
      head_num = as.numeric(csr$head),
      to = as.integer(csr$to),
      wt = as.numeric(csr$wt),
      wl = as.numeric(csr$wl),
      src_node = as.integer(src_idx),
      cutoff = as.numeric(cutoff_s)
    )

    n_reached_edges <- length(res$edge_from)
    if (n_reached_edges == 0) {
      next
    }

    # Extract lines corresponding to (edge_from, edge_to)
    from_u <- res$edge_from
    to_v <- res$edge_to
    net_edges <- network$edges

    # Match in network edges
    match_mask <- (net_edges$from_node %in% from_u & net_edges$to_node %in% to_v) |
                  (net_edges$from_node %in% to_v & net_edges$to_node %in% from_u)

    sub_edges <- net_edges[match_mask, ]
    if (nrow(sub_edges) == 0) {
      next
    }
    sub_edges$cutoff_min <- t_min

    # Create polygon geometry
    buffered_lines <- sf::st_buffer(sf::st_combine(sub_edges$geometry), dist = buffer_m)

    poly_geom <- if (method == "concave") {
      # Try concave hull on buffered lines
      tryCatch({
        ch <- sf::st_concave_hull(buffered_lines, ratio = concave_ratio)
        sf::st_make_valid(ch)
      }, error = function(e) {
        sf::st_make_valid(sf::st_union(buffered_lines))
      })
    } else {
      sf::st_make_valid(sf::st_union(buffered_lines))
    }

    # If it is a GEOMETRYCOLLECTION, extract polygons safely
    geom_types <- as.character(sf::st_geometry_type(poly_geom))
    if (any(grepl("GEOMETRYCOLLECTION", geom_types))) {
      poly_geom <- sf::st_collection_extract(poly_geom, "POLYGON")
    }

    area_val <- as.numeric(sf::st_area(poly_geom)) / 1e6
    perim_val <- as.numeric(sf::st_length(sf::st_boundary(poly_geom))) / 1000
    net_len_km <- sum(res$edge_reached_length) / 1000.0

    p_df <- sf::st_sf(
      time_min = t_min,
      cutoff_s = cutoff_s,
      network_length_km = net_len_km,
      area_km2 = area_val,
      perimeter_km = perim_val,
      n_edges = nrow(sub_edges),
      geometry = poly_geom,
      crs = sf::st_crs(nodes)
    )

    poly_list[[as.character(t_min)]] <- p_df
    edge_list[[as.character(t_min)]] <- sub_edges
  }

  if (length(poly_list) == 0) {
    cli::cli_abort("No walkable streets reachable within specified time cutoffs from origin node {src_idx}.")
  }

  all_polys <- do.call(rbind, poly_list)
  cumulative_polys <- all_polys
  all_edges <- do.call(rbind, edge_list)

  # Construct non-overlapping concentric rings if requested and multiple cutoffs exist
  if (isTRUE(rings) && nrow(all_polys) > 1) {
    n_p <- nrow(all_polys)
    ring_rows <- list()
    for (i in seq_len(n_p)) {
      if (i == 1) {
        r_geom <- all_polys$geometry[1]
        interv <- sprintf("0 - %.0f min", all_polys$time_min[1])
        b_min <- 0.0
      } else {
        # Subtract union of smaller isochrones
        prev_union <- sf::st_union(cumulative_polys$geometry[1:(i - 1)])
        diff_geom <- sf::st_difference(all_polys$geometry[i], prev_union)
        diff_geom <- sf::st_make_valid(diff_geom)
        gtypes <- as.character(sf::st_geometry_type(diff_geom))
        if (any(grepl("GEOMETRYCOLLECTION", gtypes))) {
          diff_geom <- sf::st_collection_extract(diff_geom, "POLYGON")
        }
        r_geom <- diff_geom
        interv <- sprintf("%.0f - %.0f min", all_polys$time_min[i - 1], all_polys$time_min[i])
        b_min <- all_polys$time_min[i - 1]
      }

      if (length(r_geom) == 0 || isTRUE(sf::st_is_empty(r_geom))) {
        r_geom <- sf::st_sfc(sf::st_polygon(), crs = sf::st_crs(all_polys))
        area_val <- 0.0
        perim_val <- 0.0
      } else {
        av <- sf::st_area(r_geom)
        area_val <- if (length(av) > 0 && !is.na(av)) as.numeric(av) / 1e6 else 0.0
        pv <- sf::st_length(sf::st_boundary(r_geom))
        perim_val <- if (length(pv) > 0 && !is.na(pv)) as.numeric(pv) / 1000 else 0.0
      }

      ring_rows[[i]] <- sf::st_sf(
        time_min = all_polys$time_min[i],
        interval = interv,
        band_min = b_min,
        band_max = all_polys$time_min[i],
        cutoff_s = all_polys$cutoff_s[i],
        network_length_km = all_polys$network_length_km[i],
        area_km2 = area_val,
        perimeter_km = perim_val,
        n_edges = all_polys$n_edges[i],
        geometry = r_geom,
        crs = sf::st_crs(all_polys)
      )
    }
    all_polys <- do.call(rbind, ring_rows)
  } else if (!("interval" %in% names(all_polys))) {
    all_polys$interval <- sprintf("0 - %.0f min", all_polys$time_min)
    all_polys$band_min <- 0.0
    all_polys$band_max <- all_polys$time_min
  }

  out <- structure(
    list(
      polygons = all_polys,
      cumulative_polygons = cumulative_polys,
      rings = rings,
      edges = all_edges,
      origin = origin_sf,
      origin_node = src_idx,
      time_min = cutoffs,
      method = method,
      network = network
    ),
    class = "walk_isochrone"
  )

  out
}

#' Print Method for Walk Isochrone
#'
#' @param x A `walk_isochrone` object.
#' @param ... Additional arguments.
#' @export
print.walk_isochrone <- function(x, ...) {
  cli::cli_h1("Walkability Isochrones")
  cli::cli_bullets(c(
    "v" = paste0("Origin Node: ", cli::col_blue(x$origin_node)),
    "v" = paste0("Enveloping Method: ", cli::col_cyan(x$method)),
    "v" = paste0("Topology Type: ", if (isTRUE(x$rings)) cli::col_green("Non-overlapping concentric rings (Disjoint)") else cli::col_yellow("Cumulative envelopes")),
    "v" = paste0("Cutoffs Evaluated: ", cli::col_yellow(paste(x$time_min, "min", collapse = ", ")))
  ))

  p_df <- x$polygons
  for (i in seq_len(nrow(p_df))) {
    label <- if ("interval" %in% names(p_df)) p_df$interval[i] else sprintf("%s min", p_df$time_min[i])
    cli::cli_bullets(c(
      "*" = paste0(
        cli::col_green(sprintf("[%s]", label)),
        " Reachable length: ", sprintf("%.2f km", p_df$network_length_km[i]),
        " | Area: ", sprintf("%.2f km\u00b2", p_df$area_km2[i]),
        " | Edges: ", p_df$n_edges[i]
      )
    ))
  }
  invisible(x)
}

#' Plot Method for Walk Isochrone
#'
#' Visualizes multi-threshold isochrone polygons with layered fills.
#'
#' @param x A `walk_isochrone` object.
#' @param show_network Logical. If `TRUE`, plots background street network.
#' @param ... Additional arguments.
#' @return A `ggplot` object.
#' @export
plot.walk_isochrone <- function(x, show_network = TRUE, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  p <- ggplot2::ggplot()

  if (isTRUE(show_network) && !is.null(x$network)) {
    p <- p + ggplot2::geom_sf(data = x$network$edges, color = "#CFD8DC", linewidth = 0.4, alpha = 0.5)
  }

  polys <- x$polygons
  if ("interval" %in% names(polys)) {
    polys$label_factor <- factor(polys$interval, levels = rev(polys$interval))
  } else {
    polys$label_factor <- factor(paste0(polys$time_min, " min"),
                                levels = paste0(sort(x$time_min, decreasing = TRUE), " min"))
  }

  # Plot descending so inner bands remain sharp
  polys_ordered <- polys[order(polys$time_min, decreasing = TRUE), ]

  p <- p +
    ggplot2::geom_sf(data = polys_ordered, ggplot2::aes(fill = .data$label_factor, color = .data$label_factor), alpha = 0.45, linewidth = 0.8) +
    ggplot2::geom_sf(data = x$edges, color = "#37474F", linewidth = 0.5, alpha = 0.4) +
    ggplot2::geom_sf(data = x$origin, color = "#D90429", size = 4, shape = 21, fill = "#FFD166", stroke = 1.5) +
    ggplot2::scale_fill_viridis_d(name = "Isochrone Band", option = "viridis", direction = -1) +
    ggplot2::scale_color_viridis_d(name = "Isochrone Band", option = "viridis", direction = -1) +
    theme_walkability() +
    ggplot2::labs(
      title = "Pedestrian Walkable Isochrones",
      subtitle = sprintf("Origin node: %s | Method: %s hull | %s", x$origin_node, x$method, if (isTRUE(x$rings)) "Disjoint Rings" else "Cumulative")
    )

  p
}
