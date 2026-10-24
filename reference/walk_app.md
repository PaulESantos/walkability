# Launch the Interactive Walkability Application

Launches an interactive web application built with Shiny, `bslib`, and
`mapgl` (MapLibre GL JS) for visual exploration and quantitative
analysis of urban street networks.

## Usage

``` r
walk_app(
  network = NULL,
  host = "127.0.0.1",
  port = NULL,
  launch.browser = TRUE,
  lang = c("es", "en"),
  ...
)
```

## Arguments

- network:

  Optional initial `walk_network` object. If `NULL` (default), the app
  allows selecting among the built-in model cities (Cusco, Lima,
  Arequipa) or uploading a custom street dataset.

- host:

  Character. The IPv4 address that the application should listen on
  (default `"127.0.0.1"`).

- port:

  Integer. The TCP port that the application should listen on. Default
  is randomly selected.

- launch.browser:

  Logical. Whether to open the application in the system's default
  browser (default `TRUE`).

- lang:

  Character string specifying the initial interface language: `"es"` for
  Spanish (default) or `"en"` for English. The user can also toggle the
  language interactively at runtime via the navbar selector.

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Runs the Shiny application (returns invisible `NULL`).

## Details

The application provides dedicated, fully documented workspaces for:

- **Pedestrian Reachability (10-min Reach):** Spatial gradient of
  walkable network length with partial-edge credits in Rust.

- **Multi-Threshold Isochrones:** Concentric, non-overlapping
  topological rings (e.g. 5, 10, 15 min) or cumulative hulls.

- **Point-to-Point Routing & Circuity:** Optimal shortest path, travel
  time, and detour ratio.

- **Network Morphology & Intersection Density:** Topological node
  valence classification (cul-de-sacs, 3-way, 4-way+).

- **Scenario Simulation:** Testing street closures and pedestrianization
  with before/after comparison.

- **Documentation & Code Generator:** Detailed methodology and
  reproducible R scripts.

## Examples

``` r
if (interactive()) {
# Launch with default language (Spanish):
walk_app()

# Launch in English:
walk_app(lang = "en")

# Launch with a pre-built network:
utils::data(streets_cusco)
net <- walk_build_network(streets_cusco, verbose = FALSE)
walk_app(net, lang = "es")
}
```
