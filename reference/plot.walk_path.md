# Plot Method for Walk Path

Visualizes the shortest pedestrian path overlaid on the local street
network.

## Usage

``` r
# S3 method for class 'walk_path'
plot(x, network = NULL, ...)
```

## Arguments

- x:

  A `walk_path` object.

- network:

  Optional background `walk_network`. If `NULL`, uses the embedded
  network.

- ...:

  Additional arguments.

## Value

A `ggplot` object.
