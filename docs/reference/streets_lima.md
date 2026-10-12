# Walkable Street Network of Lima (Historic Center / Damero de Pizarro)

A spatial `sf` line dataset representing the walkable street network of
the Historic Center and Damero de Pizarro in Lima, Peru. Extracted from
OpenStreetMap and projected into UTM Zone 18S (EPSG:32718).

## Usage

``` r
streets_lima
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
  `residential`, `secondary`).

- oneway:

  Directionality tag from OSM.

- surface:

  Pavement surface type.

- geom:

  LineString geometry in EPSG:32718.

## Source

OpenStreetMap contributors (<https://www.openstreetmap.org/copyright>),
ODbL 1.0.

## Examples

``` r
data(streets_lima)
nrow(streets_lima)
#> [1] 916
```
