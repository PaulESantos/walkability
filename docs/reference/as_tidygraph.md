# Convert Walk Network to tidygraph tbl_graph

Converts a `walk_network` object into a `tbl_graph` from the `tidygraph`
package.

## Usage

``` r
as_tidygraph(x, ...)

# S3 method for class 'walk_network'
as_tidygraph(x, directed = FALSE, ...)
```

## Arguments

- x:

  A `walk_network` object.

- ...:

  Additional arguments passed to methods.

- directed:

  Logical. If `TRUE`, creates a directed graph. Default is `FALSE`.

## Value

A `tbl_graph` object if `tidygraph` is installed.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
if (requireNamespace("tidygraph", quietly = TRUE)) {
  tg <- as_tidygraph(net)
  print(tg)
}
#> # A tbl_graph: 562 nodes and 288 edges
#> #
#> # An undirected multigraph with 314 components
#> #
#> # Node Data: 562 × 4 (active)
#>    node_id component is_giant           geometry
#>      <int>     <int> <lgl>           <POINT [m]>
#>  1       0       482 TRUE     (178123.7 8503446)
#>  2       1       482 TRUE     (177744.5 8503236)
#>  3       2       482 TRUE     (177513.6 8503650)
#>  4       3       482 TRUE     (178153.6 8503156)
#>  5       4       482 TRUE     (177922.9 8503815)
#>  6       5       482 TRUE     (177437.7 8503781)
#>  7       6       482 TRUE     (177312.1 8503514)
#>  8       7       376 FALSE    (177724.3 8503413)
#>  9       8       377 FALSE    (178002.4 8503664)
#> 10       9       482 TRUE     (177493.5 8503190)
#> # ℹ 552 more rows
#> #
#> # Edge Data: 288 × 12
#>    from    to osm_id name  highway street_id                  geometry from_node
#>   <int> <int> <chr>  <chr> <chr>       <int>          <LINESTRING [m]>     <int>
#> 1     1    89 48191… Lima… primary         1 (178123.7 8503446, 17812…         0
#> 2     2   375 48197… Puen… tertia…         2 (177744.5 8503236, 17774…         1
#> 3     3   142 48197… Aven… tertia…         3 (177513.6 8503650, 17751…         2
#> # ℹ 285 more rows
#> # ℹ 4 more variables: to_node <int>, length_m <dbl>, travel_time_s <dbl>,
#> #   is_giant <lgl>
```
