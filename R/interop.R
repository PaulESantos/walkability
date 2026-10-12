#' Convert Walk Network to sfnetworks Graph
#'
#' Converts a `walk_network` object into an `sfnetwork` from the `sfnetworks` package
#' for seamless integration with spatial graph routing and tidygraph analysis workflows.
#'
#' @param x A `walk_network` object.
#' @param directed Logical. If `TRUE`, creates a directed graph. Default is `FALSE` (undirected pedestrian network).
#' @param ... Additional arguments passed to methods.
#'
#' @return An `sfnetwork` object if `sfnetworks` is installed.
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' if (requireNamespace("sfnetworks", quietly = TRUE)) {
#'   sfn <- as_sfnetwork(net)
#'   print(sfn)
#' }
as_sfnetwork <- function(x, ...) {
  UseMethod("as_sfnetwork")
}

#' @rdname as_sfnetwork
#' @export
as_sfnetwork.walk_network <- function(x, directed = FALSE, ...) {
  if (!requireNamespace("sfnetworks", quietly = TRUE)) {
    cli::cli_abort("The {.pkg sfnetworks} package is required for this conversion. Please install it with {.code install.packages('sfnetworks')}.")
  }

  edges <- x$edges
  # Ensure from and to columns match 1-indexed R row IDs in nodes
  edges$from <- edges$from_node + 1L
  edges$to <- edges$to_node + 1L

  tryCatch({
    sfnetworks::sfnetwork(
      nodes = x$nodes,
      edges = edges,
      directed = directed,
      force = TRUE,
      message = FALSE,
      ...
    )
  }, error = function(e) {
    sfnetworks::as_sfnetwork(
      edges,
      directed = directed,
      ...
    )
  })
}

#' Convert Walk Network to tidygraph tbl_graph
#'
#' Converts a `walk_network` object into a `tbl_graph` from the `tidygraph` package.
#'
#' @param x A `walk_network` object.
#' @param directed Logical. If `TRUE`, creates a directed graph. Default is `FALSE`.
#' @param ... Additional arguments passed to methods.
#'
#' @return A `tbl_graph` object if `tidygraph` is installed.
#' @export
#'
#' @examples
#' data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' if (requireNamespace("tidygraph", quietly = TRUE)) {
#'   tg <- as_tidygraph(net)
#'   print(tg)
#' }
as_tidygraph <- function(x, ...) {
  UseMethod("as_tidygraph")
}

#' @rdname as_tidygraph
#' @export
as_tidygraph.walk_network <- function(x, directed = FALSE, ...) {
  if (!requireNamespace("tidygraph", quietly = TRUE)) {
    cli::cli_abort("The {.pkg tidygraph} package is required for this conversion. Please install it with {.code install.packages('tidygraph')}.")
  }

  edges <- x$edges
  edges$from <- edges$from_node + 1L
  edges$to <- edges$to_node + 1L

  tidygraph::tbl_graph(
    nodes = as.data.frame(x$nodes),
    edges = as.data.frame(edges),
    directed = directed
  )
}
