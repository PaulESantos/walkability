#' Topological and Health Diagnosis for Street Networks
#'
#' Evaluates the topological connectivity, dangling nodes, potential undershoots,
#' and component fragmentation of a user-supplied street network before building
#' the routing graph. This function does not alter geometries, leaving repair
#' decisions to the user.
#'
#' @details
#' \subsection{Concept: Undershoots}{
#' An **undershoot** occurs when a digitized street segment terminates just short
#' of intersecting or connecting with an adjacent road, leaving a small metric gap.
#' While legitimate dead ends (cul-de-sacs) naturally exist in pedestrian networks,
#' a dangling endpoint that lies suspiciously close (within \code{snap_search_radius_m})
#' to another street is typically a digitization or vectorization defect.
#'
#' In \code{walk_diagnose_network()}, undershoots are identified in two stages:
#' \enumerate{
#'   \item All dangling endpoints (nodes with topological degree = 1) are isolated
#'     across the network.
#'   \item The minimum Euclidean distance from each dangling endpoint to all other line
#'     geometries (excluding the incident segment itself) is computed. If this distance is
#'     less than or equal to \code{snap_search_radius_m}, the endpoint is flagged as a
#'     potential undershoot.
#' }
#' In pedestrian routing, even a gap of a few centimeters forms an impassable barrier,
#' artificially forcing detours or disconnecting origins from destinations. Potential
#' undershoots can be resolved during network construction via
#' \code{\link[=walk_build_network]{walk_build_network(..., repair = TRUE, snap_tolerance_m = ...)}}.
#' }
#'
#' \subsection{Concept: Isolated Edges}{
#' **Isolated edges** are street segments that belong to disconnected components
#' (subgraphs or "islands") outside of the primary **giant component** (the largest
#' contiguous connected network).
#'
#' In \code{walk_diagnose_network()}, connectivity components are detected using a fast
#' disjoint-set (Union-Find) algorithm implemented in Rust:
#' \enumerate{
#'   \item Endpoints are matched across lines using coordinate coincidence with 1 mm precision.
#'   \item The giant component is determined as the component with the largest total network length.
#'   \item Any edge where neither endpoint connects to the giant component is labeled as an
#'     isolated edge.
#' }
#' Isolated fragments commonly arise from bounding box or polygon clipping (cutting streets
#' at administrative borders), gated communities, or disjointed municipal data layers. When
#' routing or computing isochrones, any origin or destination snapped to an isolated edge
#' will be mathematically unreachable from the rest of the city (resulting in infinite travel times).
#' }
#'
#' \subsection{Visual Inspection}{
#' Diagnostic results can be inspected visually using \code{plot(diagnosis)} or
#' \code{\link[=walk_plot_diagnosis]{walk_plot_diagnosis()}}, which renders the giant component
#' in neutral tones, highlights isolated edges in red, and marks potential undershoots with amber points.
#' }
#'
#' @param data An `sf` object containing `LINESTRING` or `MULTILINESTRING` street segments.
#' @param snap_search_radius_m Maximum distance in meters to search for potential
#'   undershoots (unconnected ends located near another segment). Default is 10.0 meters.
#' @param crs Optional target metric CRS (e.g. EPSG code or proj4string). If provided,
#'   `data` is transformed to this CRS before distance calculations.
#'
#' @return A `walk_diagnosis` S3 object containing:
#'   \item{summary}{Tibble with diagnostic statistics (segments, lengths, components, dangles, undershoots).}
#'   \item{components}{Table of detected connected components and their total lengths.}
#'   \item{undershoots}{`sf` point collection of suspicious dangling endpoints within \code{snap_search_radius_m} of another street, with column \code{dist_to_nearest_m}.}
#'   \item{isolated_edges}{`sf` line collection of edges not belonging to the giant component.}
#'   \item{data}{Original spatial line data.}
#'   \item{search_radius_m}{The search radius parameter used.}
#' @seealso \code{\link[=walk_plot_diagnosis]{walk_plot_diagnosis()}}, \code{\link[=walk_build_network]{walk_build_network()}}
#' @export
#'
#' @examples
#' data(streets_cusco)
#' diag <- walk_diagnose_network(streets_cusco, snap_search_radius_m = 5)
#' print(diag)
walk_diagnose_network <- function(data, snap_search_radius_m = 10.0, crs = NULL) {
  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} object.")
  }

  # Ensure projected metric CRS
  if (!is.null(crs)) {
    data <- sf::st_transform(data, crs)
  }
  
  if (sf::st_is_longlat(data)) {
    cli::cli_warn(c(
      "The spatial data is in geographic coordinates (degrees, EPSG:4326).",
      "i" = "Distances for snapping and lengths require a projected metric CRS (e.g. UTM).",
      "i" = "Consider passing {.code crs = <metric_epsg>}."
    ))
  }

  geom_type <- unique(as.character(sf::st_geometry_type(data)))
  if (!all(geom_type %in% c("LINESTRING", "MULTILINESTRING"))) {
    cli::cli_abort("Data must contain only LINESTRING or MULTILINESTRING geometries.")
  }

  # Cast to LINESTRING if needed
  lines <- sf::st_cast(data, "LINESTRING", warn = FALSE)
  n_edges <- nrow(lines)
  
  # Calculate lengths
  edge_lengths <- as.numeric(sf::st_length(lines))
  total_length_km <- sum(edge_lengths) / 1000.0

  # Extract endpoints
  coords <- sf::st_coordinates(lines)
  # Endpoints per line
  line_ids <- coords[, "L1"]
  
  first_idx <- which(!duplicated(line_ids))
  last_idx <- which(!duplicated(line_ids, fromLast = TRUE))
  
  start_pts <- coords[first_idx, c("X", "Y"), drop = FALSE]
  end_pts <- coords[last_idx, c("X", "Y"), drop = FALSE]

  # Node identification by coordinate rounding (1 mm precision)
  start_str <- paste(round(start_pts[, 1], 3), round(start_pts[, 2], 3), sep = "_")
  end_str <- paste(round(end_pts[, 1], 3), round(end_pts[, 2], 3), sep = "_")

  unique_nodes <- unique(c(start_str, end_str))
  n_nodes <- length(unique_nodes)
  node_map <- stats::setNames(seq_along(unique_nodes) - 1L, unique_nodes)

  u <- unname(node_map[start_str])
  v <- unname(node_map[end_str])

  # Fast Union-Find in Rust or R for component analysis
  # Rust build CSR provides exact component IDs
  csr <- rust_build_csr(
    n_nodes = as.integer(n_nodes),
    u = as.integer(u),
    v = as.integer(v),
    wt = as.numeric(edge_lengths / 1.25),
    wl = as.numeric(edge_lengths)
  )

  comp_ids <- csr$comp
  # Node degrees
  deg_table <- table(c(u, v))
  dangle_nodes <- as.integer(names(deg_table[deg_table == 1]))

  # Giant component
  giant_id <- csr$giant_comp_id
  giant_node_mask <- (comp_ids == giant_id)

  # Edge component assignment (edge belongs to giant if either endpoint does)
  edge_is_giant <- (comp_ids[u + 1L] == giant_id) | (comp_ids[v + 1L] == giant_id)
  isolated_lines <- lines[!edge_is_giant, ]
  
  isolated_length_km <- sum(edge_lengths[!edge_is_giant]) / 1000.0
  giant_length_km <- sum(edge_lengths[edge_is_giant]) / 1000.0

  # Identify potential undershoots among dangling endpoints
  # A dangle is an undershoot if it is within snap_search_radius_m of another line
  undershoot_pts <- NULL
  n_undershoots <- 0
  
  if (length(dangle_nodes) > 0 && snap_search_radius_m > 0) {
    node_coords <- do.call(rbind, strsplit(unique_nodes[dangle_nodes + 1L], "_"))
    node_coords <- matrix(as.numeric(node_coords), ncol = 2)
    dangle_sf <- sf::st_as_sf(
      as.data.frame(node_coords),
      coords = c(1, 2),
      crs = sf::st_crs(data)
    )

    # Spatial distance from dangles to street lines
    # Sample or search nearest
    raw_dist <- sf::st_distance(dangle_sf, lines)
    dist_matrix <- matrix(as.numeric(raw_dist), nrow = nrow(dangle_sf))
    # Exclude distance to the incident line itself (which is 0)
    # Replace zeros with Inf
    dist_matrix[dist_matrix < 0.001] <- Inf
    min_dist <- apply(dist_matrix, 1, min)

    is_undershoot <- (min_dist <= snap_search_radius_m)
    n_undershoots <- sum(is_undershoot)
    if (n_undershoots > 0) {
      undershoot_pts <- dangle_sf[is_undershoot, ]
      undershoot_pts$dist_to_nearest_m <- min_dist[is_undershoot]
    }
  }

  summary_tbl <- tibble::tibble(
    metric = c(
      "Total segments",
      "Total network length (km)",
      "Total intersection nodes",
      "Connected components",
      "Giant component length (km)",
      "Giant component coverage (%)",
      "Isolated network length (km)",
      "Dangling ends (dead ends)",
      paste0("Potential undershoots (<= ", snap_search_radius_m, "m)")
    ),
    value = c(
      as.character(n_edges),
      sprintf("%.2f", total_length_km),
      as.character(n_nodes),
      as.character(csr$total_components),
      sprintf("%.2f", giant_length_km),
      sprintf("%.1f%%", (giant_length_km / max(0.001, total_length_km)) * 100),
      sprintf("%.2f", isolated_length_km),
      as.character(length(dangle_nodes)),
      as.character(n_undershoots)
    )
  )

  res <- structure(
    list(
      summary = summary_tbl,
      n_edges = n_edges,
      total_length_km = total_length_km,
      total_components = csr$total_components,
      giant_length_km = giant_length_km,
      isolated_length_km = isolated_length_km,
      pct_connected = (giant_length_km / max(0.001, total_length_km)) * 100,
      n_dangles = length(dangle_nodes),
      n_undershoots = n_undershoots,
      undershoots = undershoot_pts,
      isolated_edges = isolated_lines,
      data = lines,
      search_radius_m = snap_search_radius_m
    ),
    class = "walk_diagnosis"
  )

  res
}

#' Print Method for Street Network Diagnosis
#'
#' @param x A `walk_diagnosis` object.
#' @param ... Additional arguments.
#' @export
print.walk_diagnosis <- function(x, ...) {
  cli::cli_h1("Walkability Network Health Diagnosis")
  
  cli::cli_bullets(c(
    "v" = paste0("Total network analyzed: ", cli::col_blue(x$n_edges), " segments (", sprintf("%.1f km", x$total_length_km), ")"),
    "v" = paste0("Total components detected: ", cli::col_yellow(x$total_components)),
    "*" = paste0("Giant (main) component: ", cli::col_green(sprintf("%.1f%%", x$pct_connected)), " of network (", sprintf("%.1f km", x$giant_length_km), ")")
  ))

  if (x$total_components > 1) {
    cli::cli_alert_warning(paste0(
      "Detected ", x$total_components - 1, " disconnected components / islands (",
      sprintf("%.2f km", x$isolated_length_km), ", ", sprintf("%.1f%%", 100 - x$pct_connected), " of network)."
    ))
  }

  if (x$n_undershoots > 0) {
    cli::cli_alert_info(paste0(
      "Identified ", cli::col_red(x$n_undershoots), 
      " potential undershoots (dangling ends located <= ", x$search_radius_m, " m from another street)."
    ))
    cli::cli_bullets(c(
      "!" = "Recommendation: You can fix these by running walk_build_network(..., repair = TRUE, snap_tolerance_m = ", x$search_radius_m, ")."
    ))
  } else {
    cli::cli_alert_success("No suspicious short-range undershoots detected.")
  }

  cli::cli_text("")
  cli::cli_text("Run {.code plot(diagnosis)} to inspect isolated segments and undershoots on a map.")
  invisible(x)
}

#' Plot Method for Street Network Diagnosis
#'
#' Visualizes disconnected network components and potential undershoots.
#'
#' @param x A `walk_diagnosis` object.
#' @param ... Additional arguments passed to ggplot2.
#' @return A `ggplot` object.
#' @export
plot.walk_diagnosis <- function(x, ...) {
  walk_plot_diagnosis(x, ...)
}
