# Walkable Street Network of Arequipa (Historic Center / Yanahuara)

A spatial `sf` line dataset representing the walkable street network of
the Historic Center, Plaza de Armas, and Yanahuara in Arequipa, Peru.
Extracted from OpenStreetMap and projected into UTM Zone 19S
(EPSG:32719).

## Usage

``` r
streets_arequipa
```

## Format

An `sf` data frame with `LINESTRING` geometries and columns:

- street_id:

  Unique integer identifier for each street segment.

- osm_id:

  Original OpenStreetMap way identifier.

- name:

  Street or passage name (if available).

- highway:

  OpenStreetMap road classification (e.g. `pedestrian`, `footway`,
  `residential`, `tertiary`).

- oneway:

  Directionality tag from OSM.

- surface:

  Pavement surface type.

- geom:

  LineString geometry in EPSG:32719.

## Source

OpenStreetMap contributors (<https://www.openstreetmap.org/copyright>),
ODbL 1.0.

## Examples

``` r
data(streets_arequipa)
nrow(streets_arequipa)
#> [1] 519
```
