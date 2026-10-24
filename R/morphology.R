#' Compute Intersection Density and Street Network Morphology
#'
#' Evaluates the structural morphology of a walkable street network by analyzing
#' node valence (degrees), isolating cul-de-sacs (dead ends), counting 3-way (T-junctions)
#' and 4-way+ (crossroads) intersections, and calculating density metrics.
#'
#' @param network A `walk_network` object produced by [walk_build_network()].
#' @param study_area Optional `sf` polygon defining the bounding study area.
#'   If `NULL`, the convex hull of the street network is used to compute area in km^2.
#'
#' @return A `walk_morphology` S3 object containing:
#'   \item{summary}{A named list of summary morphological metrics.}
#'   \item{nodes}{`sf` points table augmented with node `degree` and `junction_type`.}
#'   \item{network}{The input `walk_network`.}
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' morph <- walk_intersection_density(net)
#' print(morph)
walk_intersection_density <- function(network, study_area = NULL) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  nodes <- network$nodes
  edges <- network$edges
  n_nodes <- nrow(nodes)

  # Calculate degree per node from edges
  from_counts <- table(edges$from_node)
  to_counts <- table(edges$to_node)

  degrees <- integer(n_nodes)
  from_idx <- as.integer(names(from_counts)) + 1L
  to_idx <- as.integer(names(to_counts)) + 1L

  degrees[from_idx] <- degrees[from_idx] + as.integer(from_counts)
  degrees[to_idx] <- degrees[to_idx] + as.integer(to_counts)

  # Classify junction type
  types <- character(n_nodes)
  types[degrees == 1L] <- "Cul-de-sac (1-way)"
  types[degrees == 2L] <- "Passing link (2-way)"
  types[degrees == 3L] <- "T-junction (3-way)"
  types[degrees >= 4L] <- "Crossroad (4-way+)"
  types[degrees == 0L] <- "Isolated (0-way)"

  types_factor <- factor(types, levels = c("Cul-de-sac (1-way)", "Passing link (2-way)", "T-junction (3-way)", "Crossroad (4-way+)", "Isolated (0-way)"))

  nodes_aug <- nodes
  nodes_aug$degree <- degrees
  nodes_aug$junction_type <- types_factor

  # Count categories
  n_cul_de_sac <- sum(degrees == 1L)
  n_passing <- sum(degrees == 2L)
  n_3way <- sum(degrees == 3L)
  n_4way_plus <- sum(degrees >= 4L)
  n_intersections <- n_3way + n_4way_plus

  # Area calculation
  if (!is.null(study_area)) {
    if (!inherits(study_area, "sf") && !inherits(study_area, "sfc")) {
      cli::cli_abort("{.arg study_area} must be an {.cls sf} or {.cls sfc} polygon.")
    }
    study_area_proj <- sf::st_transform(study_area, sf::st_crs(nodes))
    area_km2 <- as.numeric(sum(sf::st_area(study_area_proj))) / 1e6
    area_source <- "User-provided study area"
  } else {
    # Compute convex hull
    hull <- sf::st_convex_hull(sf::st_union(nodes))
    area_km2 <- as.numeric(sf::st_area(hull)) / 1e6
    area_source <- "Convex hull of network nodes"
  }

  tot_length_km <- sum(edges$length_m) / 1000.0

  intersection_density_km2 <- if (area_km2 > 0) n_intersections / area_km2 else NA_real_
  cul_de_sac_density_km2 <- if (area_km2 > 0) n_cul_de_sac / area_km2 else NA_real_
  intersections_per_km_net <- if (tot_length_km > 0) n_intersections / tot_length_km else NA_real_

  cul_de_sac_ratio <- if (n_intersections > 0) n_cul_de_sac / n_intersections else 0.0
  grid_4way_ratio <- if (n_intersections > 0) n_4way_plus / n_intersections else 0.0
  connectivity_ratio <- if ((n_3way + n_cul_de_sac) > 0) n_4way_plus / (n_3way + n_cul_de_sac) else 0.0

  summary_stats <- list(
    total_nodes = n_nodes,
    intersections = n_intersections,
    cul_de_sacs = n_cul_de_sac,
    passing_nodes = n_passing,
    three_way_junctions = n_3way,
    four_way_plus_junctions = n_4way_plus,
    area_km2 = area_km2,
    area_source = area_source,
    network_length_km = tot_length_km,
    intersection_density_km2 = intersection_density_km2,
    cul_de_sac_density_km2 = cul_de_sac_density_km2,
    intersections_per_km_net = intersections_per_km_net,
    cul_de_sac_ratio = cul_de_sac_ratio,
    grid_4way_ratio = grid_4way_ratio,
    connectivity_ratio = connectivity_ratio,
    mean_node_degree = mean(degrees)
  )

  structure(
    list(
      summary = summary_stats,
      nodes = nodes_aug,
      network = network,
      intersection_density_km2 = intersection_density_km2,
      cul_de_sac_ratio_pct = cul_de_sac_ratio * 100,
      orthogonality_ratio_pct = grid_4way_ratio * 100
    ),
    class = "walk_morphology"
  )
}

#' Print Method for Walk Morphology
#'
#' @param x A `walk_morphology` object.
#' @param ... Additional arguments.
#' @return The `walk_morphology` object `x`, invisibly, after printing its summary.
#' @export
print.walk_morphology <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("Walkability Network Morphology & Intersection Density")
  cli::cli_bullets(c(
    "v" = paste0("Total Intersections (\u2265 3-way): ", cli::col_green(format(s$intersections, big.mark = ","))),
    "v" = paste0("Cul-de-sacs (Dead ends, 1-way): ", cli::col_red(format(s$cul_de_sacs, big.mark = ","))),
    "v" = paste0("3-way Junctions (T-junctions): ", cli::col_cyan(format(s$three_way_junctions, big.mark = ","))),
    "v" = paste0("4-way+ Crossings (Grid nodes): ", cli::col_blue(format(s$four_way_plus_junctions, big.mark = ","))),
    "*" = paste0("Intersection Density: ", cli::col_yellow(sprintf("%.1f / km\u00b2", s$intersection_density_km2)), " (", s$area_source, ")"),
    "*" = paste0("Cul-de-sac Ratio: ", cli::col_magenta(sprintf("%.1f %% of intersections", s$cul_de_sac_ratio * 100))),
    "*" = paste0("Grid Orthogonality Ratio (4-way+ / Intersections): ", sprintf("%.1f %%", s$grid_4way_ratio * 100)),
    "*" = paste0("Mean Node Degree: ", sprintf("%.2f", s$mean_node_degree))
  ))
  invisible(x)
}

#' Plot Method for Walk Morphology
#'
#' Visualizes the spatial layout of cul-de-sacs, T-junctions, and crossroads.
#'
#' @param x A `walk_morphology` object.
#' @param ... Additional arguments.
#' @return A `ggplot` object.
#' @export
plot.walk_morphology <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  # Filter out 2-way passing nodes from map for clarity, only highlight intersections & cul-de-sacs
  junctions_sf <- x$nodes[x$nodes$degree != 2L & x$nodes$degree > 0L, ]

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = x$network$edges, color = "#B0BEC5", linewidth = 0.5, alpha = 0.6) +
    ggplot2::geom_sf(
      data = junctions_sf,
      ggplot2::aes(color = .data$junction_type, size = .data$degree),
      alpha = 0.85
    ) +
    ggplot2::scale_color_manual(
      name = "Junction Type",
      values = c(
        "Cul-de-sac (1-way)" = "#E63946",
        "T-junction (3-way)" = "#457B9D",
        "Crossroad (4-way+)" = "#2A9D8F"
      )
    ) +
    ggplot2::scale_size_continuous(range = c(2, 4), guide = "none") +
    theme_walkability() +
    ggplot2::labs(
      title = "Street Network Intersection Morphology",
      subtitle = sprintf(
        "Density: %.1f intersections/km\u00b2 | Cul-de-sac ratio: %.1f%%",
        x$summary$intersection_density_km2,
        x$summary$cul_de_sac_ratio * 100
      )
    )

  p
}
