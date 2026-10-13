#' Global Variables and Namespace Imports
#'
#' @importFrom rlang .data
#' @keywords internal
"_PACKAGE"

# Silence R CMD check NOTE about NSE column names in ggplot2 and dplyr
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(".data", "betweenness_norm", "delta_reach_km"))
}
