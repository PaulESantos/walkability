# Simulate Scenario Closures and Evaluate Betweenness Re-routing

Simulates the pedestrianization or physical closure of selected street
segments and calculates the redistribution of shortest-path betweenness
centrality across the remaining network.

## Usage

``` r
walk_scenario_betweenness(
  network,
  closed_edges = NULL,
  snap_tolerance_m = 0,
  radius_m = NULL,
  verbose = TRUE
)
```

## Arguments

- network:

  A `walk_network` object.

- closed_edges:

  Integer vector of edge row indices to remove.

- snap_tolerance_m:

  Snapping tolerance in meters for network repair. Default is 0.0.

- radius_m:

  Optional metric search cutoff in meters.

- verbose:

  Logical.

## Value

A `walk_scenario_betweenness` S3 object containing comparison metrics,
augmented edges with delta betweenness, and top diverted streets.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  data(streets_cusco)
  net <- walk_build_network(streets_cusco, verbose = FALSE)
  sim <- walk_scenario_betweenness(net, closed_edges = c(5, 10))
  print(sim)
}
#> ℹ Calculando intermediación de red base...
#> ℹ Simulando cierre de 2 tramos y reconstruyendo topología...
#> ℹ Recalculando intermediación post-cierre...
#> 
#> ── Walkability: Simulación de Cierres e Intermediación ─────────────────────────
#> ℹ Tramos cerrados: 2 (220.2 m suprimidos)
#> ℹ Máximo incremento de intermediación (Δ): 534
#> 
#> ── Vías con Mayor Intermediación / Desvío Producto del Cierre: ──
#> 
#>  # ID        Nombre        Tipo Longitud (m) Intermed. Base
#>    30  Santa Monica     footway        119.2            568
#>   149   San Agustín residential         63.5           4047
#>   143 Mira Calcetas       steps         30.1            488
#>    38      Ayacucho residential        165.8            627
#>   128  Calle Matara residential        238.4             43
#>  Intermed. Post-Cierre Incremento (Delta) Norm Post-Cierre
#>                   1102                534            13.32
#>                   4526                479            54.70
#>                    940                452            11.36
#>                    844                217            10.20
#>                    248                205             3.00
```
