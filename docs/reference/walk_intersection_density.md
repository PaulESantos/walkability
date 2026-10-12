# Compute Intersection Density and Street Network Morphology

Evaluates the structural morphology of a walkable street network by
analyzing node valence (degrees), isolating cul-de-sacs (dead ends),
counting 3-way (T-junctions) and 4-way+ (crossroads) intersections, and
calculating density metrics.

## Usage

``` r
walk_intersection_density(network, study_area = NULL)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network()`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- study_area:

  Optional `sf` polygon defining the bounding study area. If `NULL`, the
  convex hull of the street network is used to compute area in km^2.

## Value

A `walk_morphology` S3 object containing:

- summary:

  A named list of summary morphological metrics.

- nodes:

  `sf` points table augmented with node `degree` and `junction_type`.

- network:

  The input `walk_network`.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
morph <- walk_intersection_density(net)
print(morph)
#> 
#> ── Walkability Network Morphology & Intersection Density ───────────────────────
#> ✔ Total Intersections (≥ 3-way): 108
#> ✔ Cul-de-sacs (Dead ends, 1-way): 71
#> ✔ 3-way Junctions (T-junctions): 67
#> ✔ 4-way+ Crossings (Grid nodes): 41
#> • Intersection Density: 46.2 / km² (Convex hull of network nodes)
#> • Cul-de-sac Ratio: 65.7 % of intersections
#> • Grid Orthogonality Ratio (4-way+ / Intersections): 38.0 %
#> • Mean Node Degree: 1.02
```
