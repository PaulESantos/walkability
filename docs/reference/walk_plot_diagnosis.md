# Plot Street Network Topological Diagnosis

Maps the health of a street network, displaying the main connected
component in neutral tones and highlighting isolated fragments and
potential undershoots.

## Usage

``` r
walk_plot_diagnosis(
  diagnosis,
  title = "Street Network Topological Health",
  dark = TRUE
)
```

## Arguments

- diagnosis:

  A `walk_diagnosis` object produced by
  [`walk_diagnose_network()`](https://walkability.github.io/walkability/reference/walk_diagnose_network.md).

- title:

  Optional custom title.

- dark:

  Logical. If `TRUE` (default), uses dark theme.

## Value

A `ggplot` object.
