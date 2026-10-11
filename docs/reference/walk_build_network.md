# Build Walkable Graph Network from Street Data

Converts user-supplied or downloaded spatial street data into a clean,
pedestrian-routing graph structure. Computes edge travel times at a
constant walking speed, optionally performs geometric repairs
(planarization, endpoint snapping) at the user's discretion, and
prepares Compressed Sparse Row (CSR) topology via compiled Rust.

## Usage

``` r
walk_build_network(
  data,
  crs = NULL,
  walk_speed_kmh = 4.5,
  repair = FALSE,
  planarize = FALSE,
  snap_tolerance_m = 0,
  keep_components = c("largest", "all"),
  drop_classes = c("motorway", "trunk"),
  drop_subclasses = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  An `sf` object with `LINESTRING` or `MULTILINESTRING` geometries.

- crs:

  Optional target metric CRS (e.g. `EPSG:32722`). If provided and `data`
  is in a different CRS, it will be projected.

- walk_speed_kmh:

  Walking design speed in km/h (default is 4.5 km/h, the international
  pedestrian planning standard, approx. 1.25 m/s).

- repair:

  Logical. If `TRUE`, applies the requested topological cleaning
  (`planarize`, `snap_tolerance_m`). If `FALSE`, preserves geometry
  exactly as provided.

- planarize:

  Logical. If `TRUE` and `repair = TRUE`, splits crossing lines at
  intersections to create valid routing junctions.

- snap_tolerance_m:

  Numeric. Threshold in meters to snap endpoint gaps. Default is 0.0 (no
  snapping). A value between 2.0 and 5.0 is recommended for imperfect
  street databases.

- keep_components:

  Character. Either `"largest"` (default) to extract the main connected
  pedestrian network, or `"all"` to retain disconnected fragments.

- drop_classes:

  Character vector of road classes to exclude (e.g.
  `c("motorway", "trunk")`). Only applied if a `class` or `highway`
  column is present in `data`.

- drop_subclasses:

  Logical. If `TRUE`, drops non-network subclasses like sidewalk,
  crosswalk, cycle_crossing, driveway, and parking_aisle if metadata
  exists.

- verbose:

  Logical. If `TRUE`, prints a summary of network construction.

## Value

A `walk_network` S3 object containing:

- nodes:

  `sf` point collection with node coordinates and IDs.

- edges:

  `sf` line collection with `length_m`, `travel_time_s`, from-node,
  to-node.

- csr:

  List with Compressed Sparse Row topology arrays (`head`, `to`, `wt`,
  `wl`, `comp`).

- walk_speed_kmh:

  The walking speed used.

- giant_comp_id:

  ID of the giant connected component.

- crs:

  The coordinate reference system of the network.

## Examples

``` r
if (FALSE) { # \dontrun{
# Standard usage with user data:
net <- walk_build_network(
  data = mis_calles,
  crs = 3116,
  repair = TRUE,
  snap_tolerance_m = 5.0,
  keep_components = "largest"
)
} # }
```
