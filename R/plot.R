#' Modern Minimalist Cartographic Theme for Walkability
#'
#' Clean theme optimized for geospatial network visualizations with ggplot2.
#'
#' @param base_size Base font size.
#' @param base_family Base font family.
#' @param dark Logical. If `TRUE` (default), uses a sleek dark theme. If `FALSE`, uses a clean white theme.
#' @export
theme_walkability <- function(base_size = 11, base_family = "", dark = TRUE) {
  bg_color <- if (dark) "#0f172a" else "#ffffff"
  text_color <- if (dark) "#f8fafc" else "#0f172a"
  sub_color <- if (dark) "#94a3b8" else "#64748b"

  ggplot2::theme_void(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = bg_color, color = NA),
      panel.background = ggplot2::element_rect(fill = bg_color, color = NA),
      plot.title = ggplot2::element_text(
        color = text_color,
        size = ggplot2::rel(1.3),
        face = "bold",
        hjust = 0,
        margin = ggplot2::margin(b = 4, t = 10, l = 10)
      ),
      plot.subtitle = ggplot2::element_text(
        color = sub_color,
        size = ggplot2::rel(0.95),
        hjust = 0,
        margin = ggplot2::margin(b = 12, l = 10)
      ),
      plot.caption = ggplot2::element_text(
        color = sub_color,
        size = ggplot2::rel(0.8),
        hjust = 1,
        margin = ggplot2::margin(t = 8, r = 10, b = 6)
      ),
      legend.position = "right",
      legend.title = ggplot2::element_text(color = text_color, size = ggplot2::rel(0.85), face = "bold"),
      legend.text = ggplot2::element_text(color = sub_color, size = ggplot2::rel(0.8)),
      legend.background = ggplot2::element_rect(fill = "transparent", color = NA),
      legend.key = ggplot2::element_rect(fill = "transparent", color = NA),
      legend.margin = ggplot2::margin(r = 10),
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
}

#' Plot Reachable Walkable Network Length Map
#'
#' Generates a publication-grade cartographic visualization of reachable walkable
#' network length using `ggplot2`. Segments are rendered in ascending order so
#' dense, high-connectivity areas (yellow) plot on top. The color scale is clipped
#' to the 2nd-98th percentiles with saturation arrows for optimal visual contrast.
#'
#' @param reach A `walk_reach` object produced by [walk_compute_reach()].
#' @param boundary Optional `sf` polygon representing the municipal or study boundary.
#' @param palette Palette name for `ggplot2::scale_color_viridis_c` (default `"viridis"`).
#' @param p_clip Percentile range for color clipping (default `c(0.02, 0.98)`).
#' @param title Optional custom title. Default highlights the isochrone budget.
#' @param subtitle Optional subtitle.
#' @param line_width Width of street lines. Default is 0.4.
#' @param dark Logical. If `TRUE` (default), renders on a dark aesthetic canvas.
#'
#' @return A `ggplot` object.
#' @export
walk_plot_reach <- function(reach,
                            boundary = NULL,
                            palette = "viridis",
                            p_clip = c(0.02, 0.98),
                            title = NULL,
                            subtitle = NULL,
                            line_width = 0.4,
                            dark = TRUE) {
  if (!inherits(reach, "walk_reach")) {
    cli::cli_abort("{.arg reach} must be a {.cls walk_reach} object.")
  }

  edges <- reach$edges
  vals <- edges$reachable_length_km

  # Color clipping bounds
  valid_vals <- vals[!is.na(vals)]
  if (length(valid_vals) > 0) {
    lims <- stats::quantile(valid_vals, probs = p_clip, na.rm = TRUE)
  } else {
    lims <- c(0, 1)
  }

  # Clip values for color aesthetic
  edges$plot_val <- pmin(pmax(edges$reachable_length_km, lims[1]), lims[2])

  # Separate valid segments from NA/unconnected segments
  valid_mask <- !is.na(edges$reachable_length_km)
  valid_edges <- edges[valid_mask, ]
  na_edges <- edges[!valid_mask, ]

  # Sort ascending so highest values draw on top
  valid_edges <- valid_edges[order(valid_edges$plot_val), ]

  cutoff_min <- round(reach$cutoff_s / 60)
  if (is.null(title)) {
    title <- paste0("Reachable Walkable Network Length (", cutoff_min, "-Minute Walk)")
  }
  if (is.null(subtitle)) {
    subtitle <- paste0("Modeled walk speed: ", reach$network$walk_speed_kmh, " km/h (~750 m budget). Yellow = high connectivity.")
  }

  na_color <- if (dark) "#334155" else "#e2e8f0"
  boundary_color <- if (dark) "#f8fafc" else "#0f172a"

  p <- ggplot2::ggplot()

  # Draw unreachable/fragmented lines in faint background tone
  if (nrow(na_edges) > 0) {
    p <- p + ggplot2::geom_sf(data = na_edges, color = na_color, linewidth = line_width * 0.7, alpha = 0.5)
  }

  # Draw valid lines colored by metric
  p <- p +
    ggplot2::geom_sf(
      data = valid_edges,
      ggplot2::aes(color = .data$plot_val),
      linewidth = line_width
    ) +
    ggplot2::scale_color_viridis_c(
      option = palette,
      name = "Reachable\nLength (km)",
      limits = c(lims[1], lims[2]),
      labels = function(x) sprintf("%.1f km", x),
      guide = ggplot2::guide_colorbar(
        barwidth = ggplot2::unit(0.8, "lines"),
        barheight = ggplot2::unit(10, "lines"),
        ticks = TRUE
      )
    )

  # Overlay boundary if provided
  if (!is.null(boundary)) {
    p <- p + ggplot2::geom_sf(
      data = boundary,
      fill = "transparent",
      color = boundary_color,
      linewidth = 0.8,
      linetype = "solid"
    )
  }

  p <- p +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      caption = "Walkability geospatial analysis | Built with R + Rust"
    ) +
    theme_walkability(dark = dark)

  p
}

#' Plot Street Network Topological Diagnosis
#'
#' Maps the health of a street network, displaying the main connected component
#' in neutral tones and highlighting isolated fragments and potential undershoots.
#'
#' @param diagnosis A `walk_diagnosis` object produced by [walk_diagnose_network()].
#' @param title Optional custom title.
#' @param dark Logical. If `TRUE` (default), uses dark theme.
#'
#' @return A `ggplot` object.
#' @export
walk_plot_diagnosis <- function(diagnosis,
                                title = "Street Network Topological Health",
                                dark = TRUE) {
  if (!inherits(diagnosis, "walk_diagnosis")) {
    cli::cli_abort("{.arg diagnosis} must be a {.cls walk_diagnosis} object.")
  }

  all_lines <- diagnosis$data
  iso_lines <- diagnosis$isolated_edges
  undershoots <- diagnosis$undershoots

  base_color <- if (dark) "#475569" else "#cbd5e1"
  alert_color <- "#ef4444" # red/coral for disconnected
  warn_color <- "#f59e0b"  # amber for undershoots

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = all_lines, color = base_color, linewidth = 0.4, alpha = 0.7)

  if (nrow(iso_lines) > 0) {
    p <- p + ggplot2::geom_sf(data = iso_lines, color = alert_color, linewidth = 0.8)
  }

  if (!is.null(undershoots) && nrow(undershoots) > 0) {
    p <- p + ggplot2::geom_sf(data = undershoots, color = warn_color, size = 2.0, shape = 21, fill = "white")
  }

  sub_text <- paste0(
    "Giant component: ", sprintf("%.1f%%", diagnosis$pct_connected), 
    " | Disconnected islands: ", nrow(iso_lines), " segments (red)"
  )
  if (!is.null(undershoots) && nrow(undershoots) > 0) {
    sub_text <- paste0(sub_text, " | Undershoots: ", nrow(undershoots), " points (amber)")
  }

  p <- p +
    ggplot2::labs(
      title = title,
      subtitle = sub_text,
      caption = "Topological validation | walkability"
    ) +
    theme_walkability(dark = dark)

  p
}
