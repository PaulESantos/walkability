# Walkable Street Network of Cusco (Historic Center)

A spatial `sf` line dataset representing the walkable street network of
the Historic Center and San Blas district in Cusco, Peru. Extracted from
OpenStreetMap and projected into UTM Zone 19S (EPSG:32719).

## Usage

``` r
streets_cusco
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
  `residential`, `steps`).

- oneway:

  Directionality tag from OSM.

- surface:

  Pavement surface type (e.g. `paved`, `cobblestone`).

- geom:

  LineString geometry in EPSG:32719.

## Source

OpenStreetMap contributors (<https://www.openstreetmap.org/copyright>),
ODbL 1.0.

## Examples

``` r
data(streets_cusco)
nrow(streets_cusco)
#> [1] 484
```
