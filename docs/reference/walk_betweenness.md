# Street Network Edge Betweenness Centrality

Computes the edge betweenness centrality for all street segments in a
walkable network. Betweenness measures the proportion of potential
shortest paths that traverse each street segment. A high value denotes a
critical bridge, connector, or structural bottleneck: if interrupted,
many potential routes are forced to divert.

## Usage

``` r
walk_betweenness(
  network,
  snap_tolerance_m = 0,
  radius_m = NULL,
  weights = "length_m",
  directed = FALSE,
  normalized = TRUE
)
```

## Arguments

- network:

  A `walk_network` object produced by
  [`walk_build_network`](https://paulesantos.github.io/walkability/reference/walk_build_network.md).

- snap_tolerance_m:

  Numeric. Radius in meters for network gap correction (snapping
  tolerance). If \> 0, repairs unconnected endpoints before graph
  construction. Default is 0.0.

- radius_m:

  Optional numeric. Maximum metric search radius (cutoff) for shortest
  paths. If `NULL` or `<= 0`, calculates global betweenness across the
  entire connected network.

- weights:

  Character string naming the edge attribute used for path lengths.
  Default is `"length_m"`.

- directed:

  Logical. If `TRUE`, considers directed edges; default is `FALSE`
  (bidirectional pedestrian walkability).

- normalized:

  Logical. If `TRUE`, adds a normalized score (0 to 100) and percentile
  rank. Default is `TRUE`.

## Value

A `walk_betweenness` S3 object containing:

- edges:

  `sf` LINESTRING data frame with columns `betweenness`,
  `betweenness_norm`, `betweenness_pctl`, and `bottleneck_class`.

- summary:

  Summary statistics of betweenness across the network.

- top_bottlenecks:

  Top street segments with highest betweenness.

- network:

  The evaluated `walk_network`.

- snap_tolerance_m:

  The snapping tolerance used.

- radius_m:

  The cutoff radius used.

## Details

### What Edge Betweenness Measures

The betweenness centrality of an edge \\e\\ is defined as: \$\$C_B(e) =
\sum\_{s \neq t} \frac{\sigma\_{st}(e)}{\sigma\_{st}}\$\$ where
\\\sigma\_{st}\\ is the total number of shortest paths from node \\s\\
to node \\t\\, and \\\sigma\_{st}(e)\\ is the number of those paths that
pass through edge \\e\\.

**Important Methodological Note:** Betweenness is a purely structural
topological metric. It is **not** a traffic volume count (aforo) nor a
congestion forecast. The tool does not assume vehicle volumes,
origin-destination matrices, travel schedules, one-way regulations, or
actual speeds. Consequently, high-betweenness (highlighted in red)
street segments represent structural network priorities, but should not
be conflated with "streets carrying the most traffic".

### Network Correction Radius

If `snap_tolerance_m > 0`, street segments with small digitization gaps
or undershoots within that metric tolerance are snapped and reconciled
before calculating shortest-path flow, avoiding artificial topological
breaks.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  data(streets_cusco)
  net <- walk_build_network(streets_cusco, verbose = FALSE)
  bw <- walk_betweenness(net)
  print(bw)
}
#> 
#> ── Walkability: Centralidad de Intermediación (Edge Betweenness) ───────────────
#> ℹ Tramos evaluados: 288 | Radio: Global | Snap: 0m
#> ℹ Intermediación máxima: 8310 | Media: 1331.6
#> 
#> ── Top Cuellos de Botella Estructurales: ──
#> 
#>  # ID                 Nombre        Tipo Longitud (m) Intermediacion
#>    53     Cuesta de San Blas residential        123.9           8310
#>    21           Hatunrumiyoc  pedestrian        109.5           7515
#>    94        Calle Plazoleta residential         59.1           7024
#>   182        Calle Plazoleta       steps         14.4           6860
#>   213 Santa Catalina Angosta residential         30.4           6792
#>  Norm (0-100) Percentil     Clasificacion
#>        100.00      100% Crítico (Top 10%)
#>         90.43     99.7% Crítico (Top 10%)
#>         84.52     99.3% Crítico (Top 10%)
#>         82.55       99% Crítico (Top 10%)
#>         81.73     98.6% Crítico (Top 10%)
#> ! Nota: Mide centralidad de ruteo potencial en la red. No es aforo ni predicción de congestión.
```
