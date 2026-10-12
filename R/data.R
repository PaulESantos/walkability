#' Walkable Street Network of Cusco (Historic Center)
#'
#' A spatial `sf` line dataset representing the walkable street network of the
#' Historic Center and San Blas district in Cusco, Peru. Extracted from
#' OpenStreetMap and projected into UTM Zone 19S (EPSG:32719).
#'
#' @format An `sf` data frame with `LINESTRING` geometries and columns:
#' \describe{
#'   \item{street_id}{Unique integer identifier for each street segment.}
#'   \item{osm_id}{Original OpenStreetMap way identifier.}
#'   \item{name}{Street or passage name (if available).}
#'   \item{highway}{OpenStreetMap road classification (e.g. `pedestrian`, `footway`, `residential`, `steps`).}
#'   \item{oneway}{Directionality tag from OSM.}
#'   \item{surface}{Pavement surface type (e.g. `paved`, `cobblestone`).}
#'   \item{geom}{LineString geometry in EPSG:32719.}
#' }
#' @source OpenStreetMap contributors (\url{https://www.openstreetmap.org/copyright}), ODbL 1.0.
#' @examples
#' data(streets_cusco)
#' nrow(streets_cusco)
"streets_cusco"

#' Walkable Street Network of Lima (Historic Center / Damero de Pizarro)
#'
#' A spatial `sf` line dataset representing the walkable street network of the
#' Historic Center and Damero de Pizarro in Lima, Peru. Extracted from
#' OpenStreetMap and projected into UTM Zone 18S (EPSG:32718).
#'
#' @format An `sf` data frame with `LINESTRING` geometries and columns:
#' \describe{
#'   \item{street_id}{Unique integer identifier for each street segment.}
#'   \item{osm_id}{Original OpenStreetMap way identifier.}
#'   \item{name}{Street or passage name (if available).}
#'   \item{highway}{OpenStreetMap road classification (e.g. `pedestrian`, `footway`, `residential`, `secondary`).}
#'   \item{oneway}{Directionality tag from OSM.}
#'   \item{surface}{Pavement surface type.}
#'   \item{geom}{LineString geometry in EPSG:32718.}
#' }
#' @source OpenStreetMap contributors (\url{https://www.openstreetmap.org/copyright}), ODbL 1.0.
#' @examples
#' data(streets_lima)
#' nrow(streets_lima)
"streets_lima"

#' Walkable Street Network of Arequipa (Historic Center / Yanahuara)
#'
#' A spatial `sf` line dataset representing the walkable street network of the
#' Historic Center, Plaza de Armas, and Yanahuara in Arequipa, Peru. Extracted from
#' OpenStreetMap and projected into UTM Zone 19S (EPSG:32719).
#'
#' @format An `sf` data frame with `LINESTRING` geometries and columns:
#' \describe{
#'   \item{street_id}{Unique integer identifier for each street segment.}
#'   \item{osm_id}{Original OpenStreetMap way identifier.}
#'   \item{name}{Street or passage name (if available).}
#'   \item{highway}{OpenStreetMap road classification (e.g. `pedestrian`, `footway`, `residential`, `tertiary`).}
#'   \item{oneway}{Directionality tag from OSM.}
#'   \item{surface}{Pavement surface type.}
#'   \item{geom}{LineString geometry in EPSG:32719.}
#' }
#' @source OpenStreetMap contributors (\url{https://www.openstreetmap.org/copyright}), ODbL 1.0.
#' @examples
#' data(streets_arequipa)
#' nrow(streets_arequipa)
"streets_arequipa"
