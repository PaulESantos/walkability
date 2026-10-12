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

#' Query Overture Maps Data via DuckDB
#'
#' Connects directly to Overture Maps Foundation's public AWS S3 Parquet dataset
#' using DuckDB's spatial and HTTPFS extensions, downloading buffered street segments
#' without requiring external CLI tools.
#'
#' @param bbox Numeric vector of length 4: `c(xmin, ymin, xmax, ymax)` in WGS84 (EPSG:4326).
#' @param output_file Optional path to save the resulting GeoParquet or GeoJSON file.
#'
#' @return An `sf` data frame of downloaded segments.
#' @export
walk_download_overture_bbox <- function(bbox, output_file = NULL) {
  if (!requireNamespace("duckdb", quietly = TRUE) || !requireNamespace("DBI", quietly = TRUE)) {
    cli::cli_abort("The {.pkg duckdb} and {.pkg DBI} packages are required. Please install them with {.code install.packages(c('duckdb', 'DBI'))}.")
  }

  if (!is.numeric(bbox) || length(bbox) != 4L || any(!is.finite(bbox))) {
    cli::cli_abort("{.arg bbox} must be four finite WGS84 coordinates: xmin, ymin, xmax, ymax.")
  }
  if (bbox[1] >= bbox[3] || bbox[2] >= bbox[4]) {
    cli::cli_abort("{.arg bbox} must satisfy xmin < xmax and ymin < ymax.")
  }

  con <- tryCatch(
    DBI::dbConnect(duckdb::duckdb()),
    error = function(e) {
      cli::cli_abort(c(
        "Could not start a DuckDB connection for the Overture query.",
        "x" = conditionMessage(e)
      ))
    }
  )
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  cli::cli_alert_info("Configuring DuckDB S3 and spatial extensions...")
  tryCatch(
    {
      DBI::dbExecute(con, "INSTALL spatial; LOAD spatial;")
      DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
      DBI::dbExecute(con, "SET s3_region='us-west-2';")
    },
    error = function(e) {
      cli::cli_abort(c(
        "Could not configure DuckDB for Overture Maps.",
        "i" = "Check the network connection and DuckDB extension availability.",
        "x" = conditionMessage(e)
      ))
    }
  )

  xmin <- bbox[1]
  ymin <- bbox[2]
  xmax <- bbox[3]
  ymax <- bbox[4]

  cli::cli_alert_info("Querying Overture Maps segments within bounding box...")
  sql <- sprintf("
    SELECT 
      id,
      subtype,
      class,
      ST_AsText(geometry) as wkt
    FROM read_parquet('s3://overturemaps-us-west-2/release/2026-09-23.1/theme=transportation/type=segment/*', hive_partitioning = 1)
    WHERE bbox.xmin <= %f AND bbox.xmax >= %f
      AND bbox.ymin <= %f AND bbox.ymax >= %f
      AND subtype = 'road'
      AND class NOT IN ('motorway', 'trunk')
    LIMIT 200000;
  ", xmax, xmin, ymax, ymin)

  df <- tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) {
      cli::cli_abort(c(
        "Could not query Overture Maps.",
        "i" = "The remote dataset may be unavailable or its release path may have changed.",
        "x" = conditionMessage(e)
      ))
    }
  )
  
  if (nrow(df) == 0) {
    cli::cli_abort("No Overture segments found in specified bounding box.")
  }

  cli::cli_alert_success("Downloaded {nrow(df)} segments from Overture Maps.")
  lines_sf <- sf::st_as_sf(df, wkt = "wkt", crs = 4326)

  if (!is.null(output_file)) {
    tryCatch(
      sf::st_write(lines_sf, output_file, delete_dsn = TRUE, quiet = TRUE),
      error = function(e) {
        cli::cli_abort(c(
          "Could not write the downloaded street data.",
          "x" = conditionMessage(e)
        ))
      }
    )
  }

  lines_sf
}
