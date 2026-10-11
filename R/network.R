#' Build Walkable Graph Network from Street Data
#'
#' Converts user-supplied or downloaded spatial street data into a clean,
#' pedestrian-routing graph structure. Computes edge travel times at a constant
#' walking speed, optionally performs geometric repairs (planarization, endpoint
#' snapping) at the user's discretion, and prepares Compressed Sparse Row (CSR)
#' topology via compiled Rust.
#'
#' @param data An `sf` object with `LINESTRING` or `MULTILINESTRING` geometries.
#' @param crs Optional target metric CRS (e.g. `EPSG:32722`). If provided and `data`
#'   is in a different CRS, it will be projected.
#' @param walk_speed_kmh Walking design speed in km/h (default is 4.5 km/h,
#'   the international pedestrian planning standard, approx. 1.25 m/s).
#' @param repair Logical. If `TRUE`, applies the requested topological cleaning
#'   (`planarize`, `snap_tolerance_m`). If `FALSE`, preserves geometry exactly as provided.
#' @param planarize Logical. If `TRUE` and `repair = TRUE`, splits crossing lines
#'   at intersections to create valid routing junctions.
#' @param snap_tolerance_m Numeric. Threshold in meters to snap endpoint gaps.
#'   Default is 0.0 (no snapping). A value between 2.0 and 5.0 is recommended for
#'   imperfect street databases.
#' @param keep_components Character. Either `"largest"` (default) to extract the
#'   main connected pedestrian network, or `"all"` to retain disconnected fragments.
#' @param drop_classes Character vector of road classes to exclude (e.g. `c("motorway", "trunk")`).
#'   Only applied if a `class` or `highway` column is present in `data`.
#' @param drop_subclasses Logical. If `TRUE`, drops non-network subclasses like
#'   sidewalk, crosswalk, cycle_crossing, driveway, and parking_aisle if metadata exists.
#' @param verbose Logical. If `TRUE`, prints a summary of network construction.
#'
#' @return A `walk_network` S3 object containing:
#'   \item{nodes}{`sf` point collection with node coordinates and IDs.}
#'   \item{edges}{`sf` line collection with `length_m`, `travel_time_s`, from-node, to-node.}
#'   \item{csr}{List with Compressed Sparse Row topology arrays (`head`, `to`, `wt`, `wl`, `comp`).}
#'   \item{walk_speed_kmh}{The walking speed used.}
#'   \item{giant_comp_id}{ID of the giant connected component.}
#'   \item{crs}{The coordinate reference system of the network.}
#' @export
#'
#' @examples
#' \dontrun{
#' # Standard usage with user data:
#' net <- walk_build_network(
#'   data = mis_calles,
#'   crs = 3116,
#'   repair = TRUE,
#'   snap_tolerance_m = 5.0,
#'   keep_components = "largest"
#' )
#' }
walk_build_network <- function(data,
                               crs = NULL,
                               walk_speed_kmh = 4.5,
                               repair = FALSE,
                               planarize = FALSE,
                               snap_tolerance_m = 0.0,
                               keep_components = c("largest", "all"),
                               drop_classes = c("motorway", "trunk"),
                               drop_subclasses = TRUE,
                               verbose = TRUE) {
  keep_components <- match.arg(keep_components)

  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} object.")
  }

  if (walk_speed_kmh <= 0) {
    cli::cli_abort("{.arg walk_speed_kmh} must be strictly positive.")
  }

  # Reproject to metric CRS if requested
  if (!is.null(crs)) {
    data <- sf::st_transform(data, crs)
  }

  if (sf::st_is_longlat(data)) {
    cli::cli_abort(c(
      "The spatial data is in geographic coordinates (degrees, EPSG:4326).",
      "x" = "Length and speed calculations require a projected metric CRS (e.g. UTM).",
      "i" = "Please specify a projected metric CRS via {.arg crs}."
    ))
  }

  # Attribute filtering if columns exist
  cols <- tolower(names(data))
  
  # Filter road classes (motorway, trunk)
  class_col <- which(cols %in% c("class", "highway", "road_class"))
  if (length(class_col) > 0 && length(drop_classes) > 0) {
    cname <- names(data)[class_col[1]]
    val_class <- tolower(as.character(data[[cname]]))
    keep_mask <- !val_class %in% tolower(drop_classes)
    n_dropped <- sum(!keep_mask, na.rm = TRUE)
    if (n_dropped > 0 && verbose) {
      cli::cli_alert_info("Filtered out {n_dropped} non-walkable segments ({paste(drop_classes, collapse = ', ')}).")
    }
    data <- data[keep_mask, ]
  }

  # Filter subclasses if requested
  subclass_col <- which(cols %in% c("subclass", "subtype"))
  if (drop_subclasses && length(subclass_col) > 0) {
    sname <- names(data)[subclass_col[1]]
    val_subclass <- tolower(as.character(data[[sname]]))
    drop_subs <- c("sidewalk", "crosswalk", "cycle_crossing", "driveway", "parking_aisle")
    keep_sub_mask <- !val_subclass %in% drop_subs
    n_dropped_sub <- sum(!keep_sub_mask, na.rm = TRUE)
    if (n_dropped_sub > 0 && verbose) {
      cli::cli_alert_info("Filtered out {n_dropped_sub} duplicate/private subclasses.")
    }
    data <- data[keep_sub_mask, ]
  }

  # Cast geometries to simple LINESTRING
  lines <- sf::st_cast(data, "LINESTRING", warn = FALSE)

  # Optional topological repair (user decision)
  if (repair) {
    if (planarize) {
      if (verbose) cli::cli_alert_info("Planarizing intersections...")
      # Planarize crossing segments
      lines <- sf::st_node(lines)
    }

    if (snap_tolerance_m > 0) {
      if (verbose) cli::cli_alert_info("Snapping endpoint gaps within {snap_tolerance_m} meters...")
      lines <- sf::st_snap(lines, lines, tolerance = snap_tolerance_m)
    }
  }

  # Extract coordinate vertices and endpoints
  coords <- sf::st_coordinates(lines)
  line_ids <- coords[, "L1"]

  first_idx <- which(!duplicated(line_ids))
  last_idx <- which(!duplicated(line_ids, fromLast = TRUE))

  start_pts <- coords[first_idx, c("X", "Y"), drop = FALSE]
  end_pts <- coords[last_idx, c("X", "Y"), drop = FALSE]

  # Compute physical lengths in meters
  lengths_m <- as.numeric(sf::st_length(lines))
  # Drop zero-length segments
  valid_geom <- lengths_m > 0.01
  lines <- lines[valid_geom, ]
  lengths_m <- lengths_m[valid_geom]
  start_pts <- start_pts[valid_geom, , drop = FALSE]
  end_pts <- end_pts[valid_geom, , drop = FALSE]

  # Map nodes with 1mm tolerance
  start_str <- paste(round(start_pts[, 1], 3), round(start_pts[, 2], 3), sep = "_")
  end_str <- paste(round(end_pts[, 1], 3), round(end_pts[, 2], 3), sep = "_")

  unique_nodes <- unique(c(start_str, end_str))
  n_nodes <- length(unique_nodes)
  node_map <- stats::setNames(seq_along(unique_nodes) - 1L, unique_nodes)

  u <- unname(node_map[start_str])
  v <- unname(node_map[end_str])

  # Calculate travel times in seconds (constant walking speed)
  # speed in m/s = speed_kmh / 3.6
  speed_ms <- walk_speed_kmh / 3.6
  travel_times_s <- lengths_m / speed_ms

  # Build graph CSR with Rust (collapsing parallel edges, dropping self-loops)
  csr <- rust_build_csr(
    n_nodes = as.integer(n_nodes),
    u = as.integer(u),
    v = as.integer(v),
    wt = as.numeric(travel_times_s),
    wl = as.numeric(lengths_m)
  )

  comp_ids <- csr$comp
  giant_id <- csr$giant_comp_id

  # Parse node coordinates
  node_coord_mat <- do.call(rbind, strsplit(unique_nodes, "_"))
  node_coord_mat <- matrix(as.numeric(node_coord_mat), ncol = 2)

  nodes_sf <- sf::st_as_sf(
    data.frame(
      node_id = 0L:(n_nodes - 1L),
      component = comp_ids,
      is_giant = (comp_ids == giant_id)
    ),
    coords = c(1, 2),
    crs = sf::st_crs(data)
  )
  sf::st_geometry(nodes_sf) <- sf::st_sfc(
    lapply(seq_len(nrow(node_coord_mat)), function(i) sf::st_point(node_coord_mat[i, ])),
    crs = sf::st_crs(data)
  )

  # Attach graph indices to lines
  lines$from_node <- u
  lines$to_node <- v
  lines$length_m <- lengths_m
  lines$travel_time_s <- travel_times_s
  lines$is_giant <- (comp_ids[u + 1L] == giant_id) & (comp_ids[v + 1L] == giant_id)

  # Filter to largest component if requested
  if (keep_components == "largest") {
    lines <- lines[lines$is_giant, ]
  }

  res <- structure(
    list(
      nodes = nodes_sf,
      edges = lines,
      csr = csr,
      walk_speed_kmh = walk_speed_kmh,
      speed_ms = speed_ms,
      giant_comp_id = giant_id,
      giant_size = csr$giant_comp_size,
      total_components = csr$total_components,
      crs = sf::st_crs(data)
    ),
    class = "walk_network"
  )

  if (verbose) {
    print(res)
  }

  res
}

#' Print Method for Walk Network
#'
#' @param x A `walk_network` object.
#' @param ... Additional arguments.
#' @export
print.walk_network <- function(x, ...) {
  cli::cli_h1("Walkability Network")
  cli::cli_bullets(c(
    "v" = paste0("Total nodes: ", cli::col_blue(nrow(x$nodes)), " (Giant component: ", cli::col_green(x$giant_size), ")"),
    "v" = paste0("Total edges: ", cli::col_blue(nrow(x$edges)), " segments (", sprintf("%.1f km", sum(x$edges$length_m) / 1000), ")"),
    "v" = paste0("Walking speed: ", cli::col_cyan(sprintf("%.1f km/h", x$walk_speed_kmh)), " (", sprintf("%.2f m/s", x$speed_ms), ")"),
    "v" = paste0("Connected components: ", cli::col_yellow(x$total_components)),
    "v" = paste0("CRS: ", cli::col_magenta(sf::st_crs(x$nodes)$input))
  ))
  invisible(x)
}
