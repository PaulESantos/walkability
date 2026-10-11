# Plot Reachable Walkable Network Length Map

Generates a publication-grade cartographic visualization of reachable
walkable network length using `ggplot2`. Segments are rendered in
ascending order so dense, high-connectivity areas (yellow) plot on top.
The color scale is clipped to the 2nd-98th percentiles with saturation
arrows for optimal visual contrast.

## Usage

``` r
walk_plot_reach(
  reach,
  boundary = NULL,
  palette = "viridis",
  p_clip = c(0.02, 0.98),
  title = NULL,
  subtitle = NULL,
  line_width = 0.4,
  dark = TRUE
)
```

## Arguments

- reach:

  A `walk_reach` object produced by
  [`walk_compute_reach()`](https://walkability.github.io/walkability/reference/walk_compute_reach.md).

- boundary:

  Optional `sf` polygon representing the municipal or study boundary.

- palette:

  Palette name for
  [`ggplot2::scale_color_viridis_c`](https://ggplot2.tidyverse.org/reference/scale_viridis.html)
  (default `"viridis"`).

- p_clip:

  Percentile range for color clipping (default `c(0.02, 0.98)`).

- title:

  Optional custom title. Default highlights the isochrone budget.

- subtitle:

  Optional subtitle.

- line_width:

  Width of street lines. Default is 0.4.

- dark:

  Logical. If `TRUE` (default), renders on a dark aesthetic canvas.

## Value

A `ggplot` object.
