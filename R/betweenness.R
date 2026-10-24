#' Street Network Edge Betweenness Centrality
#'
#' Computes the edge betweenness centrality for all street segments in a walkable
#' network. Betweenness measures the proportion of potential shortest paths that traverse
#' each street segment. A high value denotes a critical bridge, connector, or structural
#' bottleneck: if interrupted, many potential routes are forced to divert.
#'
#' @details
#' \subsection{What Edge Betweenness Measures}{
#' The betweenness centrality of an edge \eqn{e} is defined as:
#' \deqn{C_B(e) = \sum_{s \neq t} \frac{\sigma_{st}(e)}{\sigma_{st}}}
#' where \eqn{\sigma_{st}} is the total number of shortest paths from node \eqn{s} to node \eqn{t},
#' and \eqn{\sigma_{st}(e)} is the number of those paths that pass through edge \eqn{e}.
#'
#' \strong{Important Methodological Note:}
#' Betweenness is a purely structural topological metric. It is \strong{not} a traffic volume
#' count (aforo) nor a congestion forecast. The tool does not assume vehicle volumes,
#' origin-destination matrices, travel schedules, one-way regulations, or actual speeds.
#' Consequently, high-betweenness (highlighted in red) street segments represent structural
#' network priorities, but should not be conflated with "streets carrying the most traffic".
#' }
#'
#' \subsection{Network Correction Radius}{
#' If \code{snap_tolerance_m > 0}, street segments with small digitization gaps or
#' undershoots within that metric tolerance are snapped and reconciled before calculating
#' shortest-path flow, avoiding artificial topological breaks.
#' }
#'
#' @param network A \code{walk_network} object produced by \code{\link{walk_build_network}}.
#' @param snap_tolerance_m Numeric. Radius in meters for network gap correction
#'   (snapping tolerance). If > 0, repairs unconnected endpoints before graph construction. Default is 0.0.
#' @param radius_m Optional numeric. Maximum metric search radius (cutoff) for shortest paths.
#'   If \code{NULL} or \code{<= 0}, calculates global betweenness across the entire connected network.
#' @param weights Character string naming the edge attribute used for path lengths. Default is \code{"length_m"}.
#' @param directed Logical. If \code{TRUE}, considers directed edges; default is \code{FALSE} (bidirectional pedestrian walkability).
#' @param normalized Logical. If \code{TRUE}, adds a normalized score (0 to 100) and percentile rank. Default is \code{TRUE}.
#'
#' @return A \code{walk_betweenness} S3 object containing:
#'   \item{edges}{\code{sf} LINESTRING data frame with columns \code{betweenness}, \code{betweenness_norm}, \code{betweenness_pctl}, and \code{bottleneck_class}.}
#'   \item{summary}{Summary statistics of betweenness across the network.}
#'   \item{top_bottlenecks}{Top street segments with highest betweenness.}
#'   \item{network}{The evaluated \code{walk_network}.}
#'   \item{snap_tolerance_m}{The snapping tolerance used.}
#'   \item{radius_m}{The cutoff radius used.}
#' @export
#'
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   data(streets_cusco)
#'   net <- walk_build_network(streets_cusco, verbose = FALSE)
#'   bw <- walk_betweenness(net)
#'   print(bw)
#' }
walk_betweenness <- function(network,
                             snap_tolerance_m = 0.0,
                             radius_m = NULL,
                             weights = "length_m",
                             directed = FALSE,
                             normalized = TRUE) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }
  if (!requireNamespace("igraph", quietly = TRUE)) {
    cli::cli_abort("The {.pkg igraph} package is required to compute betweenness centrality. Install with {.code install.packages('igraph')}.")
  }

  net_work <- network
  # Optional network tolerance / repair radius
  if (!is.null(snap_tolerance_m) && is.numeric(snap_tolerance_m) && snap_tolerance_m > 0) {
    snapped_lines <- sf::st_snap(network$edges, network$edges, tolerance = snap_tolerance_m)
    net_work <- walk_build_network(
      data = snapped_lines,
      walk_speed_kmh = network$walk_speed_kmh,
      repair = TRUE,
      snap_tolerance_m = snap_tolerance_m,
      planarize = FALSE,
      verbose = FALSE
    )
  }

  edges_sf <- net_work$edges
  n_edges <- nrow(edges_sf)
  if (n_edges == 0) {
    cli::cli_abort("The network contains no edges.")
  }

  # Ensure edge_id column exists
  if (!"edge_id" %in% names(edges_sf)) {
    edges_sf$edge_id <- seq_len(n_edges)
  }

  # Build igraph data frame using row_id 1..n_edges
  wt_col <- if (!is.null(weights) && weights %in% names(edges_sf)) edges_sf[[weights]] else edges_sf$length_m
  wt_col <- as.numeric(wt_col)
  wt_col[is.na(wt_col) | wt_col <= 0] <- 1.0

  df_graph <- data.frame(
    from = as.character(edges_sf$from_node),
    to = as.character(edges_sf$to_node),
    row_id = seq_len(n_edges),
    weight = wt_col,
    stringsAsFactors = FALSE
  )

  g <- igraph::graph_from_data_frame(df_graph, directed = directed)

  cutoff_val <- if (!is.null(radius_m) && is.numeric(radius_m) && is.finite(radius_m) && radius_m > 0) {
    as.numeric(radius_m)
  } else {
    -1
  }

  raw_eb <- igraph::edge_betweenness(
    graph = g,
    e = igraph::E(g),
    directed = directed,
    weights = igraph::E(g)$weight,
    cutoff = cutoff_val
  )

  # Match back to original edge order via row_id
  eb_vec <- numeric(n_edges)
  eb_vec[igraph::E(g)$row_id] <- raw_eb

  max_eb <- max(eb_vec, na.rm = TRUE)
  eb_norm <- if (max_eb > 0) (eb_vec / max_eb) * 100 else rep(0, n_edges)
  eb_pctl <- round(stats::ecdf(eb_vec)(eb_vec) * 100, 1)

  # Classification of bottlenecks
  bottleneck_class <- character(n_edges)
  bottleneck_class[eb_pctl >= 90] <- "Cr\u00edtico (Top 10%)"
  bottleneck_class[eb_pctl >= 75 & eb_pctl < 90] <- "Alto (Top 25%)"
  bottleneck_class[eb_pctl >= 50 & eb_pctl < 75] <- "Medio (Conector)"
  bottleneck_class[eb_pctl < 50] <- "Bajo / Capilar"

  # Assign hex colors
  color_hex <- character(n_edges)
  color_hex[eb_pctl >= 90] <- "#D90429"      # Red
  color_hex[eb_pctl >= 75 & eb_pctl < 90] <- "#F77F00" # Orange
  color_hex[eb_pctl >= 50 & eb_pctl < 75] <- "#FCBF49" # Yellow
  color_hex[eb_pctl < 50] <- "#457B9D"      # Slate blue

  edges_sf$betweenness <- round(eb_vec, 2)
  edges_sf$betweenness_norm <- round(eb_norm, 2)
  edges_sf$betweenness_pctl <- eb_pctl
  edges_sf$bottleneck_class <- bottleneck_class
  edges_sf$color <- color_hex

  # Extract top bottlenecks
  order_idx <- order(eb_vec, decreasing = TRUE)
  top_n <- min(10L, n_edges)
  top_edges <- edges_sf[order_idx[seq_len(top_n)], ]
  top_df <- data.frame(
    `# ID` = top_edges$edge_id,
    Nombre = if ("name" %in% names(top_edges)) ifelse(is.na(top_edges$name) | top_edges$name == "", "(Sin nombre)", top_edges$name) else paste0("Tramo #", top_edges$edge_id),
    Tipo = if ("highway" %in% names(top_edges)) ifelse(is.na(top_edges$highway), "v\u00eda", top_edges$highway) else "v\u00eda",
    `Longitud (m)` = round(top_edges$length_m, 1),
    Intermediacion = round(top_edges$betweenness, 1),
    `Norm (0-100)` = top_edges$betweenness_norm,
    Percentil = paste0(top_edges$betweenness_pctl, "%"),
    Clasificacion = top_edges$bottleneck_class,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  summary_stats <- list(
    total_edges = n_edges,
    mean_betweenness = mean(eb_vec, na.rm = TRUE),
    median_betweenness = stats::median(eb_vec, na.rm = TRUE),
    max_betweenness = max_eb,
    p90_betweenness = stats::quantile(eb_vec, 0.90, na.rm = TRUE)[[1]],
    snap_tolerance_m = snap_tolerance_m,
    radius_m = if (cutoff_val > 0) cutoff_val else "Global"
  )

  structure(
    list(
      edges = edges_sf,
      summary = summary_stats,
      top_bottlenecks = top_df,
      network = net_work,
      snap_tolerance_m = snap_tolerance_m,
      radius_m = radius_m
    ),
    class = "walk_betweenness"
  )
}

#' Print Method for Walk Betweenness
#'
#' @param x A \code{walk_betweenness} object.
#' @param ... Additional arguments.
#' @return The `walk_betweenness` object `x`, invisibly, after printing its summary.
#' @export
print.walk_betweenness <- function(x, ...) {
  cli::cli_h1("Walkability: Centralidad de Intermediaci\u00f3n (Edge Betweenness)")
  cli::cli_alert_info("Tramos evaluados: {x$summary$total_edges} | Radio: {x$summary$radius_m} | Snap: {x$summary$snap_tolerance_m}m")
  cli::cli_alert_info("Intermediaci\u00f3n m\u00e1xima: {round(x$summary$max_betweenness, 1)} | Media: {round(x$summary$mean_betweenness, 1)}")
  cli::cli_h2("Top Cuellos de Botella Estructurales:")
  print(utils::head(x$top_bottlenecks, 5), row.names = FALSE)
  cli::cli_alert_warning("Nota: Mide centralidad de ruteo potencial en la red. No es aforo ni predicci\u00f3n de congesti\u00f3n.")
  invisible(x)
}

#' Plot Method for Walk Betweenness
#'
#' @param x A \code{walk_betweenness} object.
#' @param ... Additional arguments.
#' @return A \code{ggplot} object.
#' @export
plot.walk_betweenness <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("The {.pkg ggplot2} package is required for plotting.")
  }

  p <- ggplot2::ggplot(x$edges) +
    ggplot2::geom_sf(ggplot2::aes(color = .data$betweenness_norm, linewidth = .data$betweenness_norm), alpha = 0.85) +
    ggplot2::scale_color_gradientn(
      name = "Intermediaci\u00f3n\n(0 - 100)",
      colors = c("#457B9D", "#FCBF49", "#F77F00", "#D90429")
    ) +
    ggplot2::scale_linewidth_continuous(
      range = c(0.6, 2.2),
      guide = "none"
    ) +
    theme_walkability() +
    ggplot2::labs(
      title = "Centralidad de Intermediaci\u00f3n de la Red Peatonal",
      subtitle = "Tramos rojos se\u00f1alan puentes o cuellos de botella estructurales cr\u00edticos"
    )

  p
}

#' Simulate Scenario Closures and Evaluate Betweenness Re-routing
#'
#' Simulates the pedestrianization or physical closure of selected street segments
#' and calculates the redistribution of shortest-path betweenness centrality
#' across the remaining network.
#'
#' @param network A \code{walk_network} object.
#' @param closed_edges Integer vector of edge row indices to remove.
#' @param snap_tolerance_m Snapping tolerance in meters for network repair. Default is 0.0.
#' @param radius_m Optional metric search cutoff in meters.
#' @param verbose Logical.
#'
#' @return A \code{walk_scenario_betweenness} S3 object containing comparison metrics,
#'   augmented edges with delta betweenness, and top diverted streets.
#' @export
#'
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   data(streets_cusco)
#'   net <- walk_build_network(streets_cusco, verbose = FALSE)
#'   sim <- walk_scenario_betweenness(net, closed_edges = c(5, 10))
#'   print(sim)
#' }
walk_scenario_betweenness <- function(network,
                                      closed_edges = NULL,
                                      snap_tolerance_m = 0.0,
                                      radius_m = NULL,
                                      verbose = TRUE) {
  if (!inherits(network, "walk_network")) {
    cli::cli_abort("{.arg network} must be a {.cls walk_network} object.")
  }

  # Ensure edge_id exists on original network
  if (!"edge_id" %in% names(network$edges)) {
    network$edges$edge_id <- seq_len(nrow(network$edges))
  }

  # 1. Compute baseline betweenness
  if (verbose) {
    cli::cli_alert_info("Calculando intermediaci\u00f3n de red base...")
  }
  base_bw <- walk_betweenness(
    network = network,
    snap_tolerance_m = snap_tolerance_m,
    radius_m = radius_m
  )

  edges_orig <- base_bw$edges
  n_orig <- nrow(edges_orig)

  sel <- as.integer(closed_edges)
  sel <- sel[!is.na(sel) & sel >= 1 & sel <= n_orig]

  if (length(sel) == 0) {
    cli::cli_alert_warning("No valid closed_edges provided. Returning baseline betweenness.")
    return(structure(
      list(
        base = base_bw,
        sim = base_bw,
        edges = edges_orig,
        closed_indices = integer(0),
        top_diverted = data.frame(),
        network = network
      ),
      class = "walk_scenario_betweenness"
    ))
  }

  # 2. Simulate closure
  if (verbose) {
    cli::cli_alert_info("Simulando cierre de {length(sel)} tramos y reconstruyendo topolog\u00eda...")
  }
  mod_net <- walk_scenario_close(network, edge_indices = sel, name = "Simulacion_Cierres")

  # 3. Compute scenario betweenness on remaining network
  if (verbose) {
    cli::cli_alert_info("Recalculando intermediaci\u00f3n post-cierre...")
  }
  sim_bw <- walk_betweenness(
    network = mod_net,
    snap_tolerance_m = 0.0, # already snapped/closed
    radius_m = radius_m
  )

  # 4. Merge results back to the original edge geometries
  sim_edges <- sim_bw$edges
  res_edges <- edges_orig

  # Map sim values by edge_id
  sim_map <- stats::setNames(sim_edges$betweenness, as.character(sim_edges$edge_id))
  sim_norm_map <- stats::setNames(sim_edges$betweenness_norm, as.character(sim_edges$edge_id))
  sim_pctl_map <- stats::setNames(sim_edges$betweenness_pctl, as.character(sim_edges$edge_id))

  bw_sim_vec <- numeric(n_orig)
  bw_sim_norm <- numeric(n_orig)
  bw_sim_pctl <- numeric(n_orig)

  ids_char <- as.character(res_edges$edge_id)
  has_match <- ids_char %in% names(sim_map)

  bw_sim_vec[has_match] <- sim_map[ids_char[has_match]]
  bw_sim_norm[has_match] <- sim_norm_map[ids_char[has_match]]
  bw_sim_pctl[has_match] <- sim_pctl_map[ids_char[has_match]]

  is_closed <- res_edges$edge_id %in% sel
  bw_sim_vec[is_closed] <- 0
  bw_sim_norm[is_closed] <- 0
  bw_sim_pctl[is_closed] <- 0

  delta_bw <- bw_sim_vec - res_edges$betweenness

  # Status labels
  status_vec <- character(n_orig)
  status_vec[is_closed] <- "Clausurado / Peatonalizado"
  status_vec[!is_closed & delta_bw > 0.01] <- "Aumento de intermediaci\u00f3n (Desv\u00edo)"
  status_vec[!is_closed & delta_bw < -0.01] <- "Reducci\u00f3n de intermediaci\u00f3n"
  status_vec[!is_closed & abs(delta_bw) <= 0.01] <- "Sin cambio"

  # Colors for simulation view
  color_sim <- character(n_orig)
  for (i in seq_len(n_orig)) {
    if (is_closed[i]) {
      color_sim[i] <- "#111827" # Dark grey / dashed closed
    } else if (bw_sim_pctl[i] >= 90) {
      color_sim[i] <- "#D90429" # High bottleneck post-closure
    } else if (bw_sim_pctl[i] >= 75) {
      color_sim[i] <- "#F77F00"
    } else if (bw_sim_pctl[i] >= 50) {
      color_sim[i] <- "#FCBF49"
    } else {
      color_sim[i] <- "#457B9D"
    }
  }

  # Colors for delta / diversion view
  color_delta <- character(n_orig)
  max_pos_delta <- max(delta_bw[!is_closed], na.rm = TRUE)
  for (i in seq_len(n_orig)) {
    if (is_closed[i]) {
      color_delta[i] <- "#111827"
    } else if (delta_bw[i] > 0.5 * max_pos_delta && delta_bw[i] > 1) {
      color_delta[i] <- "#D90429" # Major diversion stress
    } else if (delta_bw[i] > 0.1 * max_pos_delta && delta_bw[i] > 0.1) {
      color_delta[i] <- "#F77F00" # Moderate diversion
    } else if (delta_bw[i] < -1) {
      color_delta[i] <- "#2A9D8F" # Relieved street
    } else {
      color_delta[i] <- "#94A3B8" # Neutral
    }
  }

  res_edges$betweenness_base <- res_edges$betweenness
  res_edges$betweenness_sim <- round(bw_sim_vec, 2)
  res_edges$betweenness_sim_norm <- round(bw_sim_norm, 2)
  res_edges$betweenness_sim_pctl <- bw_sim_pctl
  res_edges$delta_betweenness <- round(delta_bw, 2)
  res_edges$is_closed <- is_closed
  res_edges$status <- status_vec
  res_edges$color_sim <- color_sim
  res_edges$color_delta <- color_delta

  # Top diverted streets (open streets with biggest increase or highest post-closure score)
  open_mask <- !is_closed
  open_edges <- res_edges[open_mask, ]
  if (nrow(open_edges) > 0) {
    top_diverted_idx <- order(open_edges$delta_betweenness, decreasing = TRUE)
    top_k <- min(10L, nrow(open_edges))
    td <- open_edges[top_diverted_idx[seq_len(top_k)], ]
    td_df <- data.frame(
      `# ID` = td$edge_id,
      Nombre = if ("name" %in% names(td)) ifelse(is.na(td$name) | td$name == "", "(Sin nombre)", td$name) else paste0("Tramo #", td$edge_id),
      Tipo = if ("highway" %in% names(td)) ifelse(is.na(td$highway), "v\u00eda", td$highway) else "v\u00eda",
      `Longitud (m)` = round(td$length_m, 1),
      `Intermed. Base` = td$betweenness_base,
      `Intermed. Post-Cierre` = td$betweenness_sim,
      `Incremento (Delta)` = td$delta_betweenness,
      `Norm Post-Cierre` = td$betweenness_sim_norm,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  } else {
    td_df <- data.frame()
  }

  summary_res <- list(
    n_closed = length(sel),
    length_closed_m = sum(edges_orig$length_m[sel], na.rm = TRUE),
    max_delta = if (nrow(open_edges) > 0) max(open_edges$delta_betweenness, na.rm = TRUE) else 0,
    top_diverted_edge = if (nrow(td_df) > 0) td_df$Nombre[1] else "(Ninguno)",
    base_mean = base_bw$summary$mean_betweenness,
    sim_mean = sim_bw$summary$mean_betweenness
  )

  structure(
    list(
      base = base_bw,
      sim = sim_bw,
      edges = res_edges,
      closed_indices = sel,
      summary = summary_res,
      top_diverted = td_df,
      network = network,
      mod_network = mod_net
    ),
    class = "walk_scenario_betweenness"
  )
}

#' Print Method for Walk Scenario Betweenness
#'
#' @param x A \code{walk_scenario_betweenness} object.
#' @param ... Additional arguments.
#' @return The `walk_scenario_betweenness` object `x`, invisibly, after printing its summary.
#' @export
print.walk_scenario_betweenness <- function(x, ...) {
  cli::cli_h1("Walkability: Simulaci\u00f3n de Cierres e Intermediaci\u00f3n")
  cli::cli_alert_info("Tramos cerrados: {x$summary$n_closed} ({round(x$summary$length_closed_m, 1)} m suprimidos)")
  cli::cli_alert_info("M\u00e1ximo incremento de intermediaci\u00f3n (\u0394): {round(x$summary$max_delta, 1)}")
  cli::cli_h2("V\u00edas con Mayor Intermediaci\u00f3n / Desv\u00edo Producto del Cierre:")
  print(utils::head(x$top_diverted, 5), row.names = FALSE)
  invisible(x)
}
