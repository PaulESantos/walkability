# Compare Baseline and Intervention Scenarios

Compares structural topology and reachable walkable network length
between a baseline street network and an intervention scenario (e.g.
street closures).

## Usage

``` r
walk_compare_scenarios(base, scenario, time_min = 10, verbose = TRUE)
```

## Arguments

- base:

  Baseline `walk_network` object.

- scenario:

  Modified `walk_network` (or `walk_scenario`) object.

- time_min:

  Walking budget in minutes for reach comparison (default 10.0 min).

- verbose:

  Logical. If `TRUE`, prints comparison summary.

## Value

A `walk_comparison` S3 object.

## Examples

``` r
data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
cierre <- walk_scenario_close(net, edge_indices = c(5, 12), name = "Peatonalizacion Central")
comp <- walk_compare_scenarios(base = net, scenario = cierre, time_min = 5, verbose = FALSE)
print(comp)
#> 
#> ── Walkability Scenario Comparison ─────────────────────────────────────────────
#> ℹ Evaluation budget: 5 minutes at 4.5 km/h
#>                      Metric   Base Scenario  Delta
#>                 Total Edges 288.00   286.00  -2.00
#>         Network Length (km)  27.32    27.24  -0.08
#>       Giant Component Nodes 249.00   249.00   0.00
#>  Total Connected Components 125.00   314.00 189.00
#>             Mean Reach (km)   2.29     2.25  -0.04
#>              Max Reach (km)   4.91     4.90  -0.01
```
