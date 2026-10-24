# Convert Walk Network to sfnetworks Graph

Converts a `walk_network` object into an `sfnetwork` from the
`sfnetworks` package for seamless integration with spatial graph routing
and tidygraph analysis workflows.

## Usage

``` r
as_sfnetwork(x, ...)

# S3 method for class 'walk_network'
as_sfnetwork(x, directed = FALSE, ...)
```

## Arguments

- x:

  A `walk_network` object.

- ...:

  Additional arguments passed to methods.

- directed:

  Logical. If `TRUE`, creates a directed graph. Default is `FALSE`
  (undirected pedestrian network).

## Value

An `sfnetwork` object if `sfnetworks` is installed.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
if (requireNamespace("sfnetworks", quietly = TRUE)) {
  sfn <- as_sfnetwork(net)
  print(sfn)
}
#> # A sfnetwork with 562 nodes and 288 edges
#> #
#> # CRS:  EPSG:32719 
#> #
#> # An undirected multigraph with 314 components with spatially explicit edges
#> #
#> # Node data: 562 × 4 (active)
#>   node_id component is_giant           geometry
#>     <int>     <int> <lgl>           <POINT [m]>
#> 1       0       297 TRUE     (178123.7 8503446)
#> 2       1       297 TRUE     (177744.5 8503236)
#> 3       2       297 TRUE     (177513.6 8503650)
#> 4       3       297 TRUE     (178153.6 8503156)
#> 5       4       297 TRUE     (177922.9 8503815)
#> 6       5       297 TRUE     (177437.7 8503781)
#> # ℹ 556 more rows
#> #
#> # Edge data: 288 × 12
#>    from    to osm_id name  highway street_id                  geometry from_node
#>   <int> <int> <chr>  <chr> <chr>       <int>          <LINESTRING [m]>     <int>
#> 1     1    89 48191… Lima… primary         1 (178123.7 8503446, 17812…         0
#> 2     2   375 48197… Puen… tertia…         2 (177744.5 8503236, 17774…         1
#> 3     3   142 48197… Aven… tertia…         3 (177513.6 8503650, 17751…         2
#> # ℹ 285 more rows
#> # ℹ 4 more variables: to_node <int>, length_m <dbl>, travel_time_s <dbl>,
#> #   is_giant <lgl>
```
