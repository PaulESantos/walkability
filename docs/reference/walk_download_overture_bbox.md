# Query Overture Maps Data via DuckDB

Connects directly to Overture Maps Foundation's public AWS S3 Parquet
dataset using DuckDB's spatial and HTTPFS extensions, downloading
buffered street segments without requiring external CLI tools.

## Usage

``` r
walk_download_overture_bbox(bbox, output_file = NULL)
```

## Arguments

- bbox:

  Numeric vector of length 4: `c(xmin, ymin, xmax, ymax)` in WGS84
  (EPSG:4326).

- output_file:

  Optional path to save the resulting GeoParquet or GeoJSON file.

## Value

An `sf` data frame of downloaded segments.
