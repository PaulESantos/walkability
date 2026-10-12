#' Compute Cumulative Walkable Accessibility to Points of Interest (POIs)
#'
#' Computes cumulative pedestrian accessibility from each network junction to urban
#' facilities (e.g. schools, health centers, pharmacies, public transit stops)
#' within a walking time budget (default 10 minutes at 4.5 km/h). Uses parallel
#' compiled Rust to evaluate hundreds of thousands of shortest paths across CPU cores.
#'
#' @param network A `walk_network` object produced by [walk_build_network()].
#' @param pois An `sf` points collection containing destination facilities/POIs.
#' @param time_min Walking time threshold in minutes (default 10.0 minutes).
#' @param category_col Optional column name in `pois` indicating facility category
#'   (e.g. `"amenity"`, `"category"`, or `"type"`). If provided, calculates separate
#'   accessibility counts for each unique category.
#' @param weight_col Optional column name in `pois` indicating facility weight/capacity.
#'   Default is `NULL` (each POI counts as 1.0).
#' @param target Character string: `"largest_component"` (default) to evaluate nodes
#'   in the primary connected component, or `"all"`.
#' @param n_threads Number of CPU threads to use in parallel, from 1 to 2.
#'   The default is 2, the maximum permitted during CRAN checks.
#' @param verbose Logical. If `TRUE`, prints execution progress and summary.
#'
#' @return A `walk_access` S3 object containing:
#'   \item{nodes}{`sf` points table augmented with columns for cumulative counts and minimum walking times.}
#'   \item{summary}{Summary statistics table per category.}
#'   \item{time_min}{The evaluated walking budget in minutes.}
#'   \item{pois}{The original POI points mapped to network nodes.}
#'   \item{network}{The input `walk_network`.}
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' sample_pois <- net$nodes[net$nodes$is_giant, ][seq(1, 100, by = 20), ]
#' acc <- walk_compute_access(net, pois = sample_pois, time_min = 5, verbose = FALSE)
#' print(acc)
walk_compute_access <- function(network,
                                pois,
                                time_min = 10.0,
                                category_col = NULL,
                                weight_col = NULL,
                                target = c("largest_component", "all"),
                                n_threads = 2L,
                                verbose = TRUE) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }
  if (length(n_threads) != 1L || is.na(n_threads) || n_threads < 1L || n_threads > 2L) {
    cli::cli_abort("{.arg n_threads} must be a single integer between 1 and 2.")
  }

  if (!inherits(pois, "sf") && !inherits(pois, "sfc")) {
    cli::cli_abort("{.arg pois} must be an {.cls sf} or {.cls sfc} object.")
  }

  target <- match.arg(target)
  nodes <- network$nodes
  n_nodes <- nrow(nodes)
  csr <- network$csr

  # Align CRS
  if (sf::st_crs(pois) != sf::st_crs(nodes)) {
    pois <- sf::st_transform(pois, sf::st_crs(nodes))
  }

  # Snap POIs to nearest network node
  nearest_node_indices <- sf::st_nearest_feature(pois, nodes) - 1L # 0-indexed
  pois$snapped_node <- nearest_node_indices

  # Weights
  weights <- if (!is.null(weight_col) && weight_col %in% names(pois)) {
    as.numeric(pois[[weight_col]])
  } else {
    rep(1.0, nrow(pois))
  }

  cutoff_s <- as.numeric(time_min * 60.0)

  # Target nodes
  if (target == "largest_component") {
    target_indices <- which(nodes$is_giant) - 1L
  } else {
    target_indices <- seq_len(n_nodes) - 1L
  }

  if (verbose) {
    cli::cli_alert_info("Computing {time_min}-min pedestrian accessibility to {nrow(pois)} facilities across {length(target_indices)} junctions...")
  }

  t0 <- Sys.time()

  # Identify categories
  categories <- if (!is.null(category_col) && category_col %in% names(pois)) {
    unique(as.character(pois[[category_col]]))
  } else {
    "all_pois"
  }

  nodes_aug <- nodes
  summary_list <- list()

  for (cat in categories) {
    if (cat == "all_pois") {
      cat_mask <- rep(TRUE, nrow(pois))
      col_prefix <- "pois"
    } else {
      cat_mask <- as.character(pois[[category_col]]) == cat
      col_prefix <- tolower(gsub("[^A-Za-z0-9_]+", "_", cat))
    }

    sub_poi_nodes <- nearest_node_indices[cat_mask]
    sub_poi_weights <- weights[cat_mask]

    res <- rust_compute_access_multi(
      n_nodes = as.integer(n_nodes),
      head_num = as.numeric(csr$head),
      to = as.integer(csr$to),
      wt = as.numeric(csr$wt),
      target_nodes = as.integer(target_indices),
      poi_nodes = as.integer(sub_poi_nodes),
      poi_weights = as.numeric(sub_poi_weights),
      cutoff = as.numeric(cutoff_s),
      num_threads = as.integer(n_threads)
    )

    count_vec <- rep(NA_real_, n_nodes)
    count_vec[target_indices + 1L] <- res$accessible_count

    time_vec <- rep(NA_real_, n_nodes)
    # Convert seconds to minutes; if NaN, set NA
    t_min_vals <- res$min_time_s / 60.0
    time_vec[target_indices + 1L] <- t_min_vals

    count_colname <- paste0("access_", col_prefix, "_count")
    time_colname <- paste0("access_", col_prefix, "_min_time_min")

    nodes_aug[[count_colname]] <- count_vec
    nodes_aug[[time_colname]] <- time_vec

    valid_cnts <- count_vec[!is.na(count_vec)]
    summary_list[[cat]] <- list(
      category = cat,
      total_facilities = sum(cat_mask),
      mean_accessible = mean(valid_cnts, na.rm = TRUE),
      max_accessible = max(valid_cnts, na.rm = TRUE),
      pct_with_access = mean(valid_cnts > 0, na.rm = TRUE) * 100
    )
  }

  runtime_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (verbose) {
    cli::cli_alert_success("Finished accessibility computation in {sprintf('%.2f', runtime_s)} seconds.")
  }

  summary_df <- do.call(rbind, lapply(summary_list, as.data.frame))

  out <- structure(
    list(
      nodes = nodes_aug,
      summary = summary_df,
      time_min = time_min,
      cutoff_s = cutoff_s,
      categories = categories,
      pois = pois,
      network = network
    ),
    class = "walk_access"
  )

  if (verbose) {
    print(out)
  }

  out
}

#' Print Method for Walk Access
#'
#' @param x A `walk_access` object.
#' @param ... Additional arguments.
#' @export
print.walk_access <- function(x, ...) {
  cli::cli_h1("Walkability Cumulative POI Accessibility")
  cli::cli_bullets(c(
    "v" = paste0("Isochrone Threshold: ", cli::col_blue(sprintf("%.1f minutes", x$time_min))),
    "v" = paste0("Facilities Evaluated: ", cli::col_green(nrow(x$pois))),
    "v" = paste0("Evaluated Junctions: ", cli::col_cyan(sum(!is.na(x$nodes[[grep('count', names(x$nodes))[1]]]))))
  ))

  s <- x$summary
  for (i in seq_len(nrow(s))) {
    cli::cli_bullets(c(
      "*" = paste0(
        cli::col_yellow(sprintf("[%s]", s$category[i])),
        " Avg reachable: ", sprintf("%.1f", s$mean_accessible[i]),
        " | Max: ", s$max_accessible[i],
        " | Reachability coverage: ", sprintf("%.1f%% of network", s$pct_with_access[i])
      )
    ))
  }
  invisible(x)
}

#' Plot Method for Walk Access
#'
#' Visualizes the spatial distribution of accessible facilities from each intersection.
#'
#' @param x A `walk_access` object.
#' @param category Character string of the category to display (if multiple exist).
#' @param ... Additional arguments.
#' @return A `ggplot` object.
#' @export
plot.walk_access <- function(x, category = NULL, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  cat_name <- if (!is.null(category)) {
    category
  } else {
    x$categories[1]
  }

  col_prefix <- if (cat_name == "all_pois") "pois" else tolower(gsub("[^A-Za-z0-9_]+", "_", cat_name))
  target_col <- paste0("access_", col_prefix, "_count")

  if (!target_col %in% names(x$nodes)) {
    cli::cli_abort("Column {.val {target_col}} not found in accessibility nodes.")
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = x$network$edges, color = "#CFD8DC", linewidth = 0.4, alpha = 0.5) +
    ggplot2::geom_sf(
      data = x$nodes[!is.na(x$nodes[[target_col]]), ],
      ggplot2::aes(color = .data[[target_col]]),
      size = 1.6
    ) +
    ggplot2::geom_sf(data = x$pois, shape = 21, fill = "#FFB703", color = "#023047", size = 2.5, stroke = 1.0) +
    ggplot2::scale_color_viridis_c(
      name = "POIs Reachable",
      option = "inferno",
      direction = -1
    ) +
    theme_walkability() +
    ggplot2::labs(
      title = sprintf("Cumulative Walkable Accessibility (%s min)", x$time_min),
      subtitle = sprintf("Category: %s | Golden dots mark facility locations", cat_name)
    )

  p
}
