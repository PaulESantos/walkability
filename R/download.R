#' Download OpenStreetMap Street Network Data
#'
#' Downloads walkable street networks using OpenStreetMap via the `osmdata` package.
#'
#' @param place_name Character. Geographic name to query (e.g. `"Curitiba, Brazil"`).
#' @param buffer_m Buffer distance in meters around the bounding box. Default is 2000 meters.
#'
#' @return An `sf` data frame with line geometries.
#' @export
walk_download_osm <- function(place_name, buffer_m = 2000) {
  if (!requireNamespace("osmdata", quietly = TRUE)) {
    cli::cli_abort("The {.pkg osmdata} package is required for OSM downloads. Please install it with {.code install.packages('osmdata')}.")
  }

  cli::cli_alert_info("Querying OpenStreetMap for: {place_name}...")

  bb <- tryCatch(
    osmdata::getbb(place_name, format_out = "matrix"),
    error = function(e) {
      cli::cli_abort(c(
        "Could not retrieve a bounding box from OpenStreetMap.",
        "i" = conditionMessage(e)
      ))
    }
  )
  if (is.null(bb)) {
    cli::cli_abort("Could not resolve bounding box for place: {place_name}")
  }

  # Build overpass query for walkable highways
  q <- osmdata::opq(bbox = bb)
  q <- osmdata::add_osm_feature(
    q,
    key = "highway",
    value = c(
      "residential", "living_street", "pedestrian", "footway",
      "path", "steps", "track", "primary", "secondary", "tertiary"
    )
  )

  osm_data <- tryCatch(
    osmdata::osmdata_sf(q),
    error = function(e) {
      cli::cli_abort(c(
        "Could not download street data from the Overpass API.",
        "i" = "Check the network connection or try again later.",
        "x" = conditionMessage(e)
      ))
    }
  )
  lines <- osm_data$osm_lines

  if (is.null(lines) || nrow(lines) == 0) {
    cli::cli_abort("No street segments found for {place_name}.")
  }

  cli::cli_alert_success("Retrieved {nrow(lines)} street segments from OpenStreetMap.")
  lines
}
