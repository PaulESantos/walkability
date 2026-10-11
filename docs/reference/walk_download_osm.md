# Download OpenStreetMap Street Network Data

Downloads walkable street networks using OpenStreetMap via the `osmdata`
package.

## Usage

``` r
walk_download_osm(place_name, buffer_m = 2000)
```

## Arguments

- place_name:

  Character. Geographic name to query (e.g. `"Curitiba, Brazil"`).

- buffer_m:

  Buffer distance in meters around the bounding box. Default is 2000
  meters.

## Value

An `sf` data frame with line geometries.
