#' Launch the Interactive Walkability Application
#'
#' Launches an interactive web application built with Shiny, `bslib`, and `mapgl`
#' (MapLibre GL JS) for visual exploration and quantitative analysis of urban
#' street networks.
#'
#' The application provides dedicated, fully documented workspaces for:
#' - **Pedestrian Reachability (10-min Reach):** Spatial gradient of walkable network length with partial-edge credits in Rust.
#' - **Multi-Threshold Isochrones:** Concentric, non-overlapping topological rings (e.g. 5, 10, 15 min) or cumulative hulls.
#' - **Point-to-Point Routing & Circuity:** Optimal shortest path, travel time, and detour ratio.
#' - **Network Morphology & Intersection Density:** Topological node valence classification (cul-de-sacs, 3-way, 4-way+).
#' - **Scenario Simulation:** Testing street closures and pedestrianization with before/after comparison.
#' - **Documentation & Code Generator:** Detailed methodology and reproducible R scripts.
#'
#' @param network Optional initial `walk_network` object. If `NULL` (default),
#'   the app allows selecting among the built-in model cities (Cusco, Lima, Arequipa)
#'   or uploading a custom street dataset.
#' @param host Character. The IPv4 address that the application should listen on (default `"127.0.0.1"`).
#' @param port Integer. The TCP port that the application should listen on. Default is randomly selected.
#' @param launch.browser Logical. Whether to open the application in the system's default browser (default `TRUE`).
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return Runs the Shiny application (returns invisible `NULL`).
#' @name walk_app
#' @export
#'
#' @examples
#' \dontrun{
#' # Launch with default model datasets:
#' walk_app()
#'
#' # Launch with a pre-built network:
#' utils::data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' walk_app(net)
#' }
walk_app <- function(network = NULL,
                     host = "127.0.0.1",
                     port = NULL,
                     launch.browser = TRUE,
                     ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort("The {.pkg shiny} package is required to launch the interactive app. Install with {.code install.packages('shiny')}.")
  }
  if (!requireNamespace("bslib", quietly = TRUE)) {
    cli::cli_abort("The {.pkg bslib} package is required to render the application interface. Install with {.code install.packages('bslib')}.")
  }
  if (!requireNamespace("mapgl", quietly = TRUE)) {
    cli::cli_abort("The {.pkg mapgl} package is required for MapLibre GPU vector rendering. Install with {.code install.packages('mapgl')}.")
  }

  app_ui <- .create_walk_app_ui(has_initial_net = !is.null(network))
  app_server <- .create_walk_app_server(initial_network = network)

  app <- shiny::shinyApp(ui = app_ui, server = app_server)
  shiny::runApp(app, host = host, port = port, launch.browser = launch.browser, ...)
}

# Internal UI Definition
.create_walk_app_ui <- function(has_initial_net = FALSE) {
  theme <- bslib::bs_theme(
    version = 5,
    bootswatch = "cosmo",
    primary = "#005F73",
    secondary = "#0A9396",
    success = "#2A9D8F",
    info = "#94D2BD",
    warning = "#E9D8A6",
    danger = "#AE2012",
    base_font = bslib::font_google("Inter"),
    code_font = bslib::font_google("Fira Code")
  )

  bslib::page_navbar(
    title = shiny::div(
      shiny::tags$span(style = "font-weight: 800; color: #005F73; font-size: 1.25rem;", "walkability"),
      shiny::tags$span(style = "font-size: 0.85rem; color: #0A9396; margin-left: 6px; font-weight: 500;", "| Transitabilidad Urbana & An\u00e1lisis de Grafos")
    ),
    header = shiny::tagList(
      shiny::tags$head(
        # KaTeX for instant, reliable LaTeX math rendering
        shiny::tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"),
        shiny::tags$script(defer = NA, src = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"),
        shiny::tags$script(defer = NA, src = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"),
        # MathJax inline configuration
        shiny::tags$script(type = "text/x-mathjax-config", shiny::HTML("
          MathJax.Hub.Config({
            tex2jax: {
              inlineMath: [['$','$'], ['\\\\(','\\\\)']],
              displayMath: [['$$','$$'], ['\\\\[','\\\\]']],
              processEscapes: true
            }
          });
        ")),
        shiny::tags$script(shiny::HTML("
          function typesetWalkabilityMath() {
            if (window.renderMathInElement) {
              renderMathInElement(document.body, {
                delimiters: [
                  {left: '$$', right: '$$', display: true},
                  {left: '\\\\[', right: '\\\\]', display: true},
                  {left: '$', right: '$', display: false},
                  {left: '\\\\(', right: '\\\\)', display: false}
                ],
                throwOnError: false
              });
            }
            if (window.MathJax && window.MathJax.Hub) {
              window.MathJax.Hub.Queue(['Typeset', window.MathJax.Hub]);
            } else if (window.MathJax && window.MathJax.typesetPromise) {
              window.MathJax.typesetPromise();
            }
          }
          document.addEventListener('DOMContentLoaded', function() {
            window.setTimeout(typesetWalkabilityMath, 200);
          });
          $(document).on('shiny:connected shown.bs.tab shiny:value shiny:idle', function() {
            window.setTimeout(typesetWalkabilityMath, 150);
          });
        "))
      ),
      shiny::withMathJax()
    ),
    theme = theme,
    fillable = TRUE,
    navbar_options = bslib::navbar_options(collapsible = TRUE),

    # Sidebar global para selecci\u00f3n de red
    sidebar = bslib::sidebar(
      title = "Configuraci\u00f3n de Red",
      width = 300,
      shiny::selectInput(
        inputId = "city_choice",
        label = "Seleccionar Red Urbana:",
        choices = c(
          "Cusco (Centro Hist\u00f3rico)" = "cusco",
          "Lima (Damero de Pizarro)" = "lima",
          "Arequipa (Yanahuara / Centro)" = "arequipa",
          "Cargar GeoPackage / Shapefile propio" = "custom"
        ),
        selected = "cusco"
      ),
      shiny::conditionalPanel(
        condition = "input.city_choice == 'custom'",
        shiny::fileInput(
          inputId = "user_file",
          label = "Subir archivo espacial (.gpkg, .geojson, .zip):",
          accept = c(".gpkg", ".geojson", ".json", ".zip")
        )
      ),
      shiny::hr(),
      shiny::numericInput(
        inputId = "param_speed",
        label = "Velocidad de caminata (km/h):",
        value = 4.5,
        min = 2.0,
        max = 8.0,
        step = 0.5
      ),
      shiny::checkboxInput(
        inputId = "param_repair",
        label = "Reparar red (snap & planarize)",
        value = TRUE
      ),
      shiny::uiOutput("network_status_badge"),
      shiny::hr(),
      shiny::tags$div(
        style = "font-size: 0.8rem; color: #6c757d;",
        shiny::tags$p("Motor Rust multi-hilo compilado con ", shiny::tags$strong("Rayon"), "."),
        shiny::tags$p("Renderizado cartogr\u00e1fico acelerado por GPU con ", shiny::tags$strong("MapLibre GL"), " v\u00eda mapgl.")
      )
    ),

    # 1. PESTA\u00d1A: ALCANCE PEATONAL
    bslib::nav_panel(
      title = "\U0001f6b6 Alcance Peatonal (Reach)",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "Par\u00e1metros de Alcance",
          width = 280,
          shiny::sliderInput(
            inputId = "reach_time_min",
            label = "Presupuesto de tiempo (minutos):",
            min = 2,
            max = 20,
            value = 10,
            step = 1
          ),
          shiny::actionButton(
            inputId = "btn_calc_reach",
            label = "Recalcular Alcance",
            class = "btn-primary w-100",
            icon = shiny::icon("play")
          ),
          shiny::hr(),
          bslib::value_box(
            title = "Alcance Promedio",
            value = shiny::textOutput("reach_stat_mean"),
            showcase = shiny::icon("person-walking"),
            theme = "primary"
          ),
          bslib::value_box(
            title = "Alcance M\u00e1ximo",
            value = shiny::textOutput("reach_stat_max"),
            showcase = shiny::icon("award"),
            theme = "secondary"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Mapa de Longitud de Red Accesible (MapLibre GL)"),
          mapgl::maplibreOutput("map_reach", height = "520px")
        ),
        bslib::card(
          bslib::card_header("\U0001f4d6 Fundamento Te\u00f3rico y Consideraciones Metodol\u00f3gicas"),
          shiny::HTML("
            <h5>M\u00e9trica de Red Caminable en $X$ Minutos (10-Minute Walk Reach)</h5>
            <p>Esta m\u00e9trica cuantifica la <strong>longitud total de calles f\u00edsicamente alcanzables</strong> a pie desde cada cruce o esquina de la ciudad dentro de un horizonte temporal determinado (por defecto <strong>10 minutos</strong>, aproximadamente 750 metros a una velocidad de dise\u00f1o de 4.5 km/h).</p>
            <h6>\u00bfPor qu\u00e9 es superior al radio euclidiano tradicional?</h6>
            <p>Los an\u00e1lisis urbanos convencionales suelen trazar c\u00edrculos de radio fijo (p. ej., \u00abis\u00f3cronas de \u00e1rea circular de 800 m\u00bb). Este enfoque ignora por completo la morfolog\u00eda del tejido urbano, la presencia de barreras f\u00edsicas (r\u00edos, laderas, avenidas sin cruces) y la estructura de cul-de-sacs. <code>walkability</code> eval\u00faa la conectividad sobre la red real de calles.</p>
            <h6>Regla de Cr\u00e9dito Parcial de Aristas (Rust Kernel)</h6>
            <p>A diferencia de librer\u00edas como <code>osmnx</code> o <code>igraph</code> que descartan o computan completas las aristas donde se agota el tiempo, <code>walkability</code> calcula algebraicamente la fracci\u00f3n exacta alcanzada:</p>
            <div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">
              $$\\ell_{\\text{frac}} = L_{(u, v)} \\times \\left(\\frac{B - t(u)}{w_{(u, v)}}\\right)$$
            </div>
            <p>Donde $B$ es el presupuesto de tiempo, $t(u)$ el tiempo acumulado hasta el nodo $u$, $w_{(u, v)}$ el tiempo de cruce del tramo y $L_{(u, v)}$ su longitud f\u00edsica en metros.</p>
          ")
        )
      )
    ),

    # 2. PESTA\u00d1A: IS\u00d3CRONAS MULTITEMPORALES
    bslib::nav_panel(
      title = "\u23f1\ufe0f Is\u00f3cronas Multitemporales",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "Control de Is\u00f3cronas",
          width = 300,
          shiny::tags$p(
            style = "font-size: 0.85rem; color: #495057;",
            "Haz clic en cualquier calle del mapa para fijar el centro de origen de las is\u00f3cronas."
          ),
          shiny::textOutput("iso_origin_label"),
          shiny::hr(),
          shiny::checkboxGroupInput(
            inputId = "iso_cutoffs",
            label = "Horizontes de tiempo (min):",
            choices = c("5 min" = 5, "10 min" = 10, "15 min" = 15),
            selected = c(5, 10, 15)
          ),
          shiny::checkboxInput(
            inputId = "iso_rings",
            label = "Anillos conc\u00e9ntricos no superpuestos (Disjoint Rings)",
            value = TRUE
          ),
          shiny::selectInput(
            inputId = "iso_method",
            label = "M\u00e9todo de envolvente:",
            choices = c("Envolvente C\u00f3ncava (concave hull)" = "concave", "Buffer de red vial" = "buffer"),
            selected = "concave"
          ),
          shiny::actionButton(
            inputId = "btn_calc_iso",
            label = "Generar Is\u00f3cronas",
            class = "btn-success w-100",
            icon = shiny::icon("bullseye")
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Pol\u00edgonos de Is\u00f3cronas (MapLibre GL)"),
          mapgl::maplibreOutput("map_iso", height = "520px")
        ),
        bslib::card(
          bslib::card_header("Resumen de Cobertura por Banda Temporal"),
          shiny::tableOutput("table_iso_bands")
        ),
        bslib::card(
          bslib::card_header("\U0001f4d6 Consideraciones T\u00e9cnicas: Is\u00f3cronas Multitemporales No Superpuestas"),
          shiny::HTML("
            <h5>Tratamiento Topol\u00f3gico de Is\u00f3cronas Conc\u00e9ntricas</h5>
            <p>Cuando se eval\u00faan horizontes temporales m\u00faltiples (por ejemplo, <strong>5, 10 y 15 minutos</strong>), el enfoque convencional genera pol\u00edgonos acumulativos conc\u00e9ntricos donde el pol\u00edgono de 15 minutos cubre completamente a los de 10 y 5 minutos. Esto produce oclusi\u00f3n visual y ambig\u00fcedad m\u00e9trica.</p>
            <h6>Estrategia de Anillos Disjuntos (<em>Donut / Concentric Rings</em>):</h6>
            <p><code>walk_isochrone()</code> implementa una sustracci\u00f3n topol\u00f3gica booleana para garantizar que <strong>los pol\u00edgonos de cada tiempo no se superpongan</strong>:</p>
            <ul>
              <li><strong>Banda 1 (0 \u2013 5 min):</strong> Corresponde a $P_5$.</li>
              <li><strong>Banda 2 (5 \u2013 10 min):</strong> Se calcula como $R_{10} = P_{10} \\setminus P_5$ (<code>st_difference</code>).</li>
              <li><strong>Banda 3 (10 \u2013 15 min):</strong> Se calcula como $R_{15} = P_{15} \\setminus (P_5 \\cup P_{10})$.</li>
            </ul>
            <p>Cada anillo representa un intervalo mutuamente excluyente. Esto permite calcular el \u00e1rea neta y los equipamientos alcanzables espec\u00edficamente en cada salto de 5 minutos, base fundamental para el an\u00e1lisis de la <strong>\u00abCiudad de los 15 minutos\u00bb</strong>.</p>
          ")
        )
      )
    ),

    # 3. PESTA\u00d1A: RUTEO Y CIRCUIDAD
    bslib::nav_panel(
      title = "\U0001f9ed Ruteo & Circuidad",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "Ruta Origen-Destino",
          width = 300,
          shiny::radioButtons(
            inputId = "route_mode",
            label = "Modo de Clic:",
            choices = c("Fijar Punto A (Origen)" = "origin", "Fijar Punto B (Destino)" = "dest"),
            selected = "origin"
          ),
          shiny::actionButton(
            inputId = "btn_random_route",
            label = "Puntos Aleatorios",
            class = "btn-secondary w-100 mb-2",
            icon = shiny::icon("shuffle")
          ),
          shiny::actionButton(
            inputId = "btn_calc_route",
            label = "Calcular Ruta \u00d3ptima",
            class = "btn-primary w-100",
            icon = shiny::icon("route")
          ),
          shiny::hr(),
          bslib::value_box(
            title = "Distancia en Red",
            value = shiny::textOutput("route_dist"),
            showcase = shiny::icon("road"),
            theme = "primary"
          ),
          bslib::value_box(
            title = "Tiempo Estimado",
            value = shiny::textOutput("route_time"),
            showcase = shiny::icon("stopwatch"),
            theme = "secondary"
          ),
          bslib::value_box(
            title = "Ratio de Circuidad",
            value = shiny::textOutput("route_circuity"),
            showcase = shiny::icon("arrows-split-up-and-left"),
            theme = "warning"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Trazado de la Ruta \u00d3ptima (MapLibre GL)"),
          mapgl::maplibreOutput("map_route", height = "520px")
        ),
        bslib::card(
          bslib::card_header("\U0001f4d6 Consideraciones T\u00e9cnicas: Ruteo Dijkstra y Circuidad Urbana"),
          shiny::HTML("
            <h5>Ruteo Punto a Punto y M\u00e9tricas de Desv\u00edo</h5>
            <p>La funci\u00f3n <code>walk_shortest_path()</code> ejecuta una b\u00fasqueda de camino m\u00e1s corto en el motor Rust con parada temprana cuando se extrae el nodo destino del mont\u00edculo binario (<em>Min-Heap</em>).</p>
            <h6>Reconstrucci\u00f3n de Trayectorias y Geometr\u00eda</h6>
            <p>Durante la b\u00fasqueda se mantienen dos arreglos planos <code>prev_node</code> y <code>prev_edge</code>. Una vez alcanzado el destino, el trayecto se reconstruye hacia atr\u00e1s en tiempo $O(\\text{saltos})$ y se extrae la secuencia de geometr\u00edas <code>LINESTRING</code>.</p>
            <h6>Ratio de Circuidad (<em>Route Directness</em>):</h6>
            <div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">
              $$\\text{Circuity} = \\frac{\\text{Distancia sobre la red vial (m)}}{\\text{Distancia euclidiana en l\u00ednea recta (m)}}$$
            </div>
            <ul>
              <li><strong>1.0 a 1.2:</strong> Trama directa y permeable con alta eficiencia de desplazamiento peatonal.</li>
              <li><strong>1.2 a 1.4:</strong> Trama moderadamente sinuosa (t\u00edpica de centros coloniales o cuadr\u00edculas con pendientes).</li>
              <li><strong>&gt; 1.5:</strong> Trama discontinua, presencia de cul-de-sacs o barreras f\u00edsicas que obligan al peat\u00f3n a rodeos significativos.</li>
            </ul>
          ")
        )
      )
    ),

    # 4. PESTA\u00d1A: MORFOLOG\u00cdA Y CRUCES
    bslib::nav_panel(
      title = "\U0001f3d9\ufe0f Morfolog\u00eda Urbana",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "M\u00e9tricas Morfol\u00f3gicas",
          width = 300,
          shiny::checkboxGroupInput(
            inputId = "morph_classes",
            label = "Mostrar en el mapa:",
            choices = c(
              "Cul-de-sacs (1 v\u00eda, callej\u00f3n ciego)" = 1,
              "Cruces en T (3 v\u00edas)" = 3,
              "Cruces en Cuadr\u00edcula (4+ v\u00edas)" = 4
            ),
            selected = c(1, 3, 4)
          ),
          shiny::hr(),
          bslib::value_box(
            title = "Densidad de Intersecciones",
            value = shiny::textOutput("morph_density"),
            showcase = shiny::icon("map-location-dot"),
            theme = "primary"
          ),
          bslib::value_box(
            title = "Proporci\u00f3n de Cul-de-sacs",
            value = shiny::textOutput("morph_culdesac"),
            showcase = shiny::icon("ban"),
            theme = "danger"
          ),
          bslib::value_box(
            title = "Ortogonalidad (4 v\u00edas+)",
            value = shiny::textOutput("morph_ortho"),
            showcase = shiny::icon("draw-polygon"),
            theme = "success"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Tipolog\u00eda de Cruces y Manzanas (MapLibre GL)"),
          mapgl::maplibreOutput("map_morph", height = "520px")
        ),
        bslib::card(
          bslib::card_header("\U0001f4d6 Consideraciones T\u00e9cnicas: Tipolog\u00eda de Cruces y Conectividad"),
          shiny::HTML("
            <h5>Clasificaci\u00f3n de Nodos seg\u00fan Valencia Topol\u00f3gica</h5>
            <p>La conectividad de un vecindario se define por la cantidad de alternativas de ruta disponibles para el peat\u00f3n. <code>walk_intersection_density()</code> examina el grado de entrada/salida de cada nodo de la red bidireccional simplificada:</p>
            <ul>
              <li><strong>Grado 1 (Cul-de-sac):</strong> Nodos ciegos que obligan al usuario a retornar por el mismo camino. Un exceso de cul-de-sacs disminuye la transitabilidad activa.</li>
              <li><strong>Grado 2 (V\u00e9rtice de paso):</strong> V\u00e9rtices de curvatura o continuidad que no representan opciones de cruce.</li>
              <li><strong>Grado 3 (Intersecciones en T):</strong> Bifurcaciones regulares de tres ramales.</li>
              <li><strong>Grado 4+ (Cruces ortogonales):</strong> Intersecciones en cruz t\u00edpicas del damero tradicional que maximizan la permeabilidad.</li>
            </ul>
            <h6>Densidad M\u00e9trica sobre la Envolvente Convexa</h6>
            <p>Para evitar el sesgo de \u00e1reas administrativas arbitrarias, la densidad de cruces ($/\\text{km}^2$) se calcula sobre la envolvente convexa (<code>sf::st_convex_hull</code>) de la red analizada.</p>
          ")
        )
      )
    ),

    # 5. PESTA\u00d1A: SIMULACI\u00d3N DE ESCENARIOS
    bslib::nav_panel(
      title = "\U0001f6a7 Simulaci\u00f3n de Escenarios",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "Intervenciones Urbanas",
          width = 320,
          shiny::tags$p(
            style = "font-size: 0.85rem; color: #495057; margin-bottom: 8px;",
            "Haz clic en cualquier tramo del mapa para marcarlo o b\u00fascalo por nombre:"
          ),
          shiny::selectizeInput(
            inputId = "scen_edge_select",
            label = "Tramos a clausurar / peatonalizar:",
            choices = NULL,
            multiple = TRUE,
            options = list(
              placeholder = "Escribe el nombre de la calle o ID...",
              maxOptions = 100,
              plugins = list("remove_button")
            )
          ),
          shiny::uiOutput("scen_selected_info"),
          shiny::div(
            class = "d-flex gap-2 mb-2",
            shiny::actionButton(
              inputId = "btn_clear_scen",
              label = "Limpiar",
              class = "btn-sm btn-outline-danger w-50",
              icon = shiny::icon("trash")
            ),
            shiny::actionButton(
              inputId = "btn_sample_random",
              label = "Elegir al azar",
              class = "btn-sm btn-outline-secondary w-50",
              icon = shiny::icon("shuffle")
            )
          ),
          shiny::sliderInput(
            inputId = "scen_random_n",
            label = "Cantidad para muestreo al azar:",
            min = 1,
            max = 15,
            value = 3,
            step = 1
          ),
          shiny::actionButton(
            inputId = "btn_sim_scenario",
            label = "Simular Intervenci\u00f3n",
            class = "btn-warning w-100 fw-bold",
            icon = shiny::icon("traffic-light")
          ),
          shiny::hr(),
          bslib::value_box(
            title = "Variaci\u00f3n de Alcance",
            value = shiny::textOutput("scen_delta_reach"),
            showcase = shiny::icon("chart-line"),
            theme = "danger"
          ),
          bslib::value_box(
            title = "Longitud Suprimida",
            value = shiny::textOutput("scen_closed_len"),
            showcase = shiny::icon("scissors"),
            theme = "secondary"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Impacto Espacial de la Intervenci\u00f3n (MapLibre GL)"),
          mapgl::maplibreOutput("map_scenarios", height = "520px")
        ),
        bslib::card(
          bslib::card_header("Detalle de Tramos Seleccionados para la Intervenci\u00f3n"),
          shiny::tableOutput("table_closed_edges")
        ),
        bslib::card(
          bslib::card_header("\U0001f4d6 Consideraciones T\u00e9cnicas: Modelado de Supermanzanas y Cortes"),
          shiny::HTML("
            <h5>Simulaci\u00f3n No Destructiva de Escenarios</h5>
            <p>Las funciones <code>walk_scenario_close()</code> y <code>walk_compare_scenarios()</code> permiten modelar intervenciones como:</p>
            <ul>
              <li>Peatonalizaci\u00f3n de corredores centrales.</li>
              <li>Clausura temporal de tramos por obras o contingencias.</li>
              <li>Creaci\u00f3n de <strong>supermanzanas</strong> (<em>superblocks</em>).</li>
            </ul>
            <p>El grafo resultante se reconstruye de forma instant\u00e1nea en memoria sin releer archivos vectoriales de disco, permitiendo evaluar la resiliencia de la red y el impacto en la accesibilidad de cada predio.</p>
          ")
        )
      )
    ),

    # 6. PESTA\u00d1A: GU\u00cdA Y REPRODUCIBILIDAD
    bslib::nav_panel(
      title = "\U0001f4d6 Gu\u00eda & C\u00f3digo R",
      bslib::card(
        bslib::card_header("Reproducibilidad en Scripts de R"),
        shiny::markdown("
Puedes replicar cualquiera de los an\u00e1lisis de esta aplicaci\u00f3n de forma program\u00e1tica con el siguiente flujo de c\u00f3digo:

```r
library(walkability)
library(sf)

# 1. Cargar red vial real
utils::data(streets_cusco)

# 2. Construir grafo estructurado
net <- walk_build_network(streets_cusco, walk_speed_kmh = 4.5, repair = TRUE)

# 3. Alcance a 10 minutos (Rust multi-hilo)
reach <- walk_compute_reach(net, time_min = 10.0)

# 4. Is\u00f3cronas conc\u00e9ntricas sin superposici\u00f3n (0-5, 5-10, 10-15 min)
centro <- st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]
iso <- walk_isochrone(net, origin = centro, time_min = c(5, 10, 15), rings = TRUE)

# 5. Ruteo punto a punto y circuidad
destino <- st_coordinates(net$nodes[net$nodes$is_giant, ])[50, 1:2]
ruta <- walk_shortest_path(net, from = centro, to = destino)

# 6. Morfolog\u00eda y cruces
morf <- walk_intersection_density(net)

# 7. Simulaci\u00f3n de cierre vial
cierre <- walk_scenario_close(net, edge_indices = c(5, 12))
comp <- walk_compare_scenarios(base = net, scenario = cierre, time_min = 5.0)
```
        ")
      )
    )
  )
}

# Internal Server Definition
.create_walk_app_server <- function(initial_network = NULL) {
  function(input, output, session) {
    # 1. Reactive Network Management
    current_net <- shiny::reactiveVal(initial_network)

    shiny::observe({
      city <- input$city_choice
      if (city == "custom") {
        shiny::req(input$user_file)
        data_path <- input$user_file$datapath
        custom_sf <- sf::st_read(data_path, quiet = TRUE)
        net <- walk_build_network(
          data = custom_sf,
          walk_speed_kmh = input$param_speed,
          repair = input$param_repair,
          verbose = FALSE
        )
        current_net(net)
      } else {
        if (city == "cusco") {
          utils::data(streets_cusco, package = "walkability", envir = environment())
          net_data <- streets_cusco
        } else if (city == "lima") {
          utils::data(streets_lima, package = "walkability", envir = environment())
          net_data <- streets_lima
        } else {
          utils::data(streets_arequipa, package = "walkability", envir = environment())
          net_data <- streets_arequipa
        }
        net <- walk_build_network(
          data = net_data,
          walk_speed_kmh = input$param_speed,
          repair = input$param_repair,
          verbose = FALSE
        )
        current_net(net)
      }
    })

    output$network_status_badge <- shiny::renderUI({
      net <- current_net()
      if (is.null(net)) return(NULL)
      shiny::tags$div(
        class = "alert alert-success p-2 mt-2",
        style = "font-size: 0.85rem;",
        shiny::tags$strong("Red cargada: "), sprintf("%s nodos | %s tramos (%.1f km)",
          nrow(net$nodes), nrow(net$edges), sum(net$edges$length_m) / 1000)
      )
    })

    # Transform network edges to WGS84 for MapLibre
    net_edges_4326 <- shiny::reactive({
      net <- current_net()
      if (is.null(net)) return(NULL)
      sf::st_transform(net$edges, 4326)
    })

    net_nodes_4326 <- shiny::reactive({
      net <- current_net()
      if (is.null(net)) return(NULL)
      sf::st_transform(net$nodes, 4326)
    })

    # -------------------------------------------------------------
    # 2. PESTA\u00d1A: ALCANCE (REACH)
    # -------------------------------------------------------------
    reach_res <- shiny::reactiveVal(NULL)

    shiny::observe({
      net <- current_net()
      shiny::req(net)
      t_min <- input$reach_time_min
      r <- walk_compute_reach(net, time_min = t_min, verbose = FALSE)
      reach_res(r)
    }) |> shiny::bindEvent(input$btn_calc_reach, current_net(), ignoreNULL = FALSE)

    output$reach_stat_mean <- shiny::renderText({
      r <- reach_res()
      if (is.null(r)) return("--")
      sprintf("%.2f km", r$summary$mean_km)
    })

    output$reach_stat_max <- shiny::renderText({
      r <- reach_res()
      if (is.null(r)) return("--")
      sprintf("%.2f km", r$summary$max_km)
    })

    output$map_reach <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      r <- reach_res()
      if (!is.null(r)) {
        # Color edges by reachable length
        lens <- r$edges$reachable_length_km
        min_v <- stats::quantile(lens, 0.05, na.rm = TRUE)
        max_v <- stats::quantile(lens, 0.95, na.rm = TRUE)
        if (max_v <= min_v) max_v <- min_v + 1
        norm_v <- pmin(pmax((lens - min_v) / (max_v - min_v), 0), 1)
        pal <- scales::col_numeric("viridis", domain = c(0, 1))
        edges_wgs$color <- pal(norm_v)
      } else {
        edges_wgs$color <- "#0A9396"
      }

      edges_wgs$tooltip_text <- sprintf("Alcance medio: %.2f km", edges_wgs$reachable_length_km %||% 0)

      mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control() |>
        mapgl::add_line_layer(
          id = "reach_edges",
          source = edges_wgs,
          line_color = mapgl::get_column("color"),
          line_width = 3,
          line_opacity = 0.85,
          tooltip = "tooltip_text"
        )
    })

    # -------------------------------------------------------------
    # 3. PESTA\u00d1A: IS\u00d3CRONAS (ISOCHRONES)
    # -------------------------------------------------------------
    iso_origin_coords <- shiny::reactiveVal(NULL)
    iso_res <- shiny::reactiveVal(NULL)

    # Detect click on isochrone map
    shiny::observeEvent(input$map_iso_click, {
      click <- input$map_iso_click
      if (!is.null(click$lng) && !is.null(click$lat)) {
        iso_origin_coords(c(click$lng, click$lat))
      }
    })

    output$iso_origin_label <- shiny::renderText({
      coords <- iso_origin_coords()
      if (is.null(coords)) {
        "Origen: Nodo central predeterminado (o haz clic en el mapa)"
      } else {
        sprintf("Origen fijado en: [%.5f, %.5f]", coords[1], coords[2])
      }
    })

    shiny::observe({
      net <- current_net()
      shiny::req(net)
      coords <- iso_origin_coords()
      cutoffs <- as.numeric(input$iso_cutoffs)
      if (length(cutoffs) == 0) cutoffs <- c(5, 10)

      if (is.null(coords)) {
        giant_nodes <- net$nodes[net$nodes$is_giant, ]
        pt_origin <- sf::st_coordinates(giant_nodes)[1, 1:2]
      } else {
        pt_wgs <- sf::st_sfc(sf::st_point(coords), crs = 4326)
        pt_proj <- sf::st_transform(pt_wgs, sf::st_crs(net$nodes))
        pt_origin <- sf::st_coordinates(pt_proj)[1, 1:2]
      }

      iso <- walk_isochrone(
        network = net,
        origin = pt_origin,
        time_min = cutoffs,
        method = input$iso_method,
        rings = input$iso_rings
      )
      iso_res(iso)
    }) |> shiny::bindEvent(input$btn_calc_iso, current_net(), ignoreNULL = FALSE)

    output$table_iso_bands <- shiny::renderTable({
      iso <- iso_res()
      if (is.null(iso)) return(data.frame())
      p <- sf::st_drop_geometry(iso$polygons)
      cols <- c("interval", "time_min", "area_km2", "network_length_km", "n_edges")
      cols <- intersect(cols, names(p))
      res_tab <- p[, cols]
      names(res_tab) <- c("Banda Temporal", "L\u00edmite (min)", "\u00c1rea (km\u00b2)", "Red Alcanzable (km)", "Tramos")[seq_along(cols)]
      res_tab
    })

    output$map_iso <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      m <- mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control() |>
        mapgl::add_line_layer(
          id = "bg_streets",
          source = edges_wgs,
          line_color = "#90A4AE",
          line_width = 1.2,
          line_opacity = 0.45
        )

      iso <- iso_res()
      if (!is.null(iso)) {
        polys_wgs <- sf::st_transform(iso$polygons, 4326)
        # Assign colors per ring
        band_colors <- c("#2A9D8F", "#E76F51", "#7209B7", "#005F73", "#E9D8A6")
        polys_wgs$color <- band_colors[(seq_len(nrow(polys_wgs)) - 1) %% length(band_colors) + 1]
        polys_wgs$popup_text <- sprintf("<strong>Banda: %s</strong><br>\u00c1rea: %.2f km\u00b2<br>Red: %.2f km",
          polys_wgs$interval %||% paste(polys_wgs$time_min, "min"),
          polys_wgs$area_km2,
          polys_wgs$network_length_km)

        m <- m |>
          mapgl::add_fill_layer(
            id = "iso_polys",
            source = polys_wgs,
            fill_color = mapgl::get_column("color"),
            fill_opacity = 0.45,
            popup = "popup_text"
          ) |>
          mapgl::add_line_layer(
            id = "iso_borders",
            source = polys_wgs,
            line_color = mapgl::get_column("color"),
            line_width = 2
          )

        # Plot origin marker
        orig_wgs <- sf::st_transform(iso$origin, 4326)
        m <- m |>
          mapgl::add_circle_layer(
            id = "iso_center",
            source = orig_wgs,
            circle_color = "#E63946",
            circle_radius = 6,
            circle_stroke_width = 2,
            circle_stroke_color = "#FFFFFF"
          )
      }
      m
    })

    # -------------------------------------------------------------
    # 4. PESTA\u00d1A: RUTEO & CIRCUIDAD (ROUTING)
    # -------------------------------------------------------------
    route_pt_a <- shiny::reactiveVal(NULL)
    route_pt_b <- shiny::reactiveVal(NULL)
    route_res <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$map_route_click, {
      click <- input$map_route_click
      if (!is.null(click$lng) && !is.null(click$lat)) {
        if (input$route_mode == "origin") {
          route_pt_a(c(click$lng, click$lat))
        } else {
          route_pt_b(c(click$lng, click$lat))
        }
      }
    })

    shiny::observeEvent(input$btn_random_route, {
      net <- current_net()
      shiny::req(net)
      nodes_proj <- net$nodes[net$nodes$is_giant, ]
      n_cand <- nrow(nodes_proj)
      if (n_cand >= 20) {
        idx_a <- sample(seq_len(n_cand), 1)
        idx_b <- sample(seq_len(n_cand), 1)
        c_a <- sf::st_coordinates(sf::st_transform(nodes_proj[idx_a, ], 4326))[1, 1:2]
        c_b <- sf::st_coordinates(sf::st_transform(nodes_proj[idx_b, ], 4326))[1, 1:2]
        route_pt_a(c_a)
        route_pt_b(c_b)
      }
    })

    shiny::observe({
      net <- current_net()
      shiny::req(net)
      pa <- route_pt_a()
      pb <- route_pt_b()
      shiny::req(pa, pb)

      # Project points to network CRS
      sfc_a <- sf::st_transform(sf::st_sfc(sf::st_point(pa), crs = 4326), sf::st_crs(net$nodes))
      sfc_b <- sf::st_transform(sf::st_sfc(sf::st_point(pb), crs = 4326), sf::st_crs(net$nodes))

      tryCatch({
        r <- walk_shortest_path(net, from = sf::st_coordinates(sfc_a)[1, 1:2], to = sf::st_coordinates(sfc_b)[1, 1:2])
        route_res(r)
      }, error = function(e) {
        route_res(NULL)
      })
    }) |> shiny::bindEvent(input$btn_calc_route, input$btn_random_route)

    output$route_dist <- shiny::renderText({
      r <- route_res()
      if (is.null(r)) return("--")
      sprintf("%.1f m (%.2f km)", r$distance_m, r$distance_m / 1000)
    })

    output$route_time <- shiny::renderText({
      r <- route_res()
      if (is.null(r)) return("--")
      sprintf("%.1f min", r$time_min)
    })

    output$route_circuity <- shiny::renderText({
      r <- route_res()
      if (is.null(r)) return("--")
      sprintf("%.3f", r$circuity)
    })

    output$map_route <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      m <- mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control() |>
        mapgl::add_line_layer(
          id = "route_bg_streets",
          source = edges_wgs,
          line_color = "#CFD8DC",
          line_width = 1.2,
          line_opacity = 0.5
        )

      pa <- route_pt_a()
      pb <- route_pt_b()

      if (!is.null(pa)) {
        pt_a_sf <- sf::st_sf(label = "Origen (A)", geometry = sf::st_sfc(sf::st_point(pa), crs = 4326))
        m <- m |> mapgl::add_circle_layer(
          id = "marker_a",
          source = pt_a_sf,
          circle_color = "#2A9D8F",
          circle_radius = 8,
          circle_stroke_width = 2,
          circle_stroke_color = "#FFFFFF"
        )
      }

      if (!is.null(pb)) {
        pt_b_sf <- sf::st_sf(label = "Destino (B)", geometry = sf::st_sfc(sf::st_point(pb), crs = 4326))
        m <- m |> mapgl::add_circle_layer(
          id = "marker_b",
          source = pt_b_sf,
          circle_color = "#E76F51",
          circle_radius = 8,
          circle_stroke_width = 2,
          circle_stroke_color = "#FFFFFF"
        )
      }

      r <- route_res()
      if (!is.null(r) && !is.null(r$path_sf)) {
        path_wgs <- sf::st_transform(r$path_sf, 4326)
        path_wgs$tooltip_text <- sprintf("Ruta: %.1f m | %.1f min | Circuidad: %.2f", r$distance_m, r$time_min, r$circuity)
        m <- m |> mapgl::add_line_layer(
          id = "route_path",
          source = path_wgs,
          line_color = "#005F73",
          line_width = 5,
          line_opacity = 0.95,
          tooltip = "tooltip_text"
        )
      }
      m
    })

    # -------------------------------------------------------------
    # 5. PESTA\u00d1A: MORFOLOG\u00cdA URBANA (MORPHOLOGY)
    # -------------------------------------------------------------
    morph_res <- shiny::reactive({
      net <- current_net()
      shiny::req(net)
      walk_intersection_density(net)
    })

    output$morph_density <- shiny::renderText({
      m <- morph_res()
      if (is.null(m)) return("--")
      sprintf("%.1f / km\u00b2", m$intersection_density_km2)
    })

    output$morph_culdesac <- shiny::renderText({
      m <- morph_res()
      if (is.null(m)) return("--")
      sprintf("%.1f %%", m$cul_de_sac_ratio_pct)
    })

    output$morph_ortho <- shiny::renderText({
      m <- morph_res()
      if (is.null(m)) return("--")
      sprintf("%.1f %%", m$orthogonality_ratio_pct)
    })

    output$map_morph <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      m_calc <- morph_res()
      shiny::req(m_calc)
      nodes_sf <- sf::st_transform(m_calc$nodes, 4326)

      # Filter selected classes
      selected_classes <- as.integer(input$morph_classes)
      if (length(selected_classes) == 0) {
        nodes_filtered <- nodes_sf[0, ]
      } else {
        nodes_filtered <- nodes_sf[nodes_sf$degree %in% selected_classes |
                                   (4 %in% selected_classes & nodes_sf$degree >= 4), ]
      }

      # Color classification
      pal_deg <- function(d) {
        ifelse(d == 1, "#E63946", ifelse(d == 3, "#457B9D", "#2A9D8F"))
      }
      if (nrow(nodes_filtered) > 0) {
        nodes_filtered$color <- pal_deg(nodes_filtered$degree)
        nodes_filtered$type_label <- sprintf("Tipo: %s (Grado %s)", nodes_filtered$junction_type, nodes_filtered$degree)
      } else {
        nodes_filtered$color <- character(0)
        nodes_filtered$type_label <- character(0)
      }

      m <- mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control() |>
        mapgl::add_line_layer(
          id = "morph_streets",
          source = edges_wgs,
          line_color = "#B0BEC5",
          line_width = 1.2,
          line_opacity = 0.5
        )

      if (nrow(nodes_filtered) > 0) {
        m <- m |>
          mapgl::add_circle_layer(
            id = "morph_nodes",
            source = nodes_filtered,
            circle_color = mapgl::get_column("color"),
            circle_radius = 5,
            circle_stroke_width = 1.5,
            circle_stroke_color = "#FFFFFF",
            tooltip = "type_label"
          )
      }
      m
    })

    # -------------------------------------------------------------
    # 6. PESTA\u00d1A: ESCENARIOS (SCENARIOS)
    # -------------------------------------------------------------
    scen_res <- shiny::reactiveVal(NULL)

    # Populate edge choices when network loads or changes
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      edges <- net$edges
      n_edges <- nrow(edges)
      if (n_edges > 0) {
        choices_vec <- as.character(seq_len(n_edges))
        names(choices_vec) <- vapply(seq_len(n_edges), function(i) {
          nm <- if ("name" %in% names(edges) && !is.na(edges$name[i]) && nzchar(trimws(edges$name[i]))) {
            edges$name[i]
          } else {
            paste0("Tramo #", i)
          }
          hw <- if ("highway" %in% names(edges) && !is.na(edges$highway[i])) edges$highway[i] else "calle"
          sprintf("%s [#%d | %.0fm | %s]", nm, i, edges$length_m[i], hw)
        }, character(1))
        shiny::updateSelectizeInput(
          session,
          "scen_edge_select",
          choices = choices_vec,
          selected = character(0),
          server = TRUE
        )
      }
      scen_res(NULL)
    })

    # Interactive map click to toggle street segment selection
    shiny::observeEvent(input$map_scenarios_click, {
      clk <- input$map_scenarios_click
      shiny::req(clk, clk$lng, clk$lat)
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)

      pt <- sf::st_sfc(sf::st_point(c(clk$lng, clk$lat)), crs = 4326)
      near_idx <- sf::st_nearest_feature(pt, edges_wgs)
      if (length(near_idx) == 1 && !is.na(near_idx)) {
        curr <- as.character(input$scen_edge_select)
        target_str <- as.character(near_idx)
        if (target_str %in% curr) {
          new_sel <- setdiff(curr, target_str)
        } else {
          new_sel <- c(curr, target_str)
        }
        shiny::updateSelectizeInput(session, "scen_edge_select", selected = new_sel)
      }
    })

    # Clear selection button
    shiny::observeEvent(input$btn_clear_scen, {
      shiny::updateSelectizeInput(session, "scen_edge_select", selected = character(0))
      scen_res(NULL)
    })

    # Random sample selection button
    shiny::observeEvent(input$btn_sample_random, {
      net <- current_net()
      shiny::req(net)
      n_edges <- nrow(net$edges)
      n_pick <- if (!is.null(input$scen_random_n)) input$scen_random_n else 3
      k <- min(n_pick, n_edges)
      if (k > 0) {
        sampled <- sample(seq_len(n_edges), k)
        shiny::updateSelectizeInput(session, "scen_edge_select", selected = as.character(sampled))
      }
    })

    # Badge showing total selected count and length
    output$scen_selected_info <- shiny::renderUI({
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      net <- current_net()
      if (length(sel) == 0 || is.null(net)) {
        return(shiny::tags$p(
          style = "font-size: 0.8rem; color: #6c757d; font-style: italic; margin-top: 4px;",
          "Ning\u00fan tramo seleccionado. Haz clic en el mapa o b\u00fascalos arriba."
        ))
      }
      valid_sel <- sel[sel >= 1 & sel <= nrow(net$edges)]
      total_m <- sum(net$edges$length_m[valid_sel], na.rm = TRUE)
      shiny::tags$div(
        class = "alert alert-info py-1 px-2 my-2",
        style = "font-size: 0.82rem;",
        shiny::tags$strong(sprintf("%d tramo(s) marcado(s)", length(valid_sel))),
        shiny::tags$span(sprintf(" \u2014 %.1f m (%.2f km)", total_m, total_m / 1000))
      )
    })

    # Run simulation on user-selected segments
    shiny::observeEvent(input$btn_sim_scenario, {
      net <- current_net()
      shiny::req(net)
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      valid_edges <- sel[sel >= 1 & sel <= nrow(net$edges)]
      if (length(valid_edges) == 0) {
        shiny::showNotification("Por favor selecciona o marca al menos un tramo antes de simular.", type = "warning")
        return()
      }
      shiny::withProgress(message = "Simulando intervenci\u00f3n urbana...", value = 0.3, {
        mod_net <- walk_scenario_close(net, edge_indices = valid_edges, name = "Intervenci\u00f3n Peatonal")
        shiny::incProgress(0.4, detail = "Calculando variaci\u00f3n de accesibilidad...")
        comp <- walk_compare_scenarios(base = net, scenario = mod_net, time_min = 5.0, verbose = FALSE)
        shiny::incProgress(0.3, detail = "Listo")
        scen_res(list(comp = comp, closed_edges = valid_edges, mod_net = mod_net))
      })
    })

    output$scen_delta_reach <- shiny::renderText({
      s <- scen_res()
      if (is.null(s) || is.null(s$comp)) return("--")
      tab <- s$comp$summary
      if (!is.data.frame(tab)) return("--")
      delta_row <- tab[tab$Metric == "Mean Reach (km)", ]
      if (nrow(delta_row) > 0 && !is.na(delta_row$Delta[1])) sprintf("%.3f km", delta_row$Delta[1]) else "--"
    })

    output$scen_closed_len <- shiny::renderText({
      s <- scen_res()
      if (is.null(s) || is.null(s$comp)) return("--")
      tab <- s$comp$summary
      if (!is.data.frame(tab)) return("--")
      delta_row <- tab[tab$Metric == "Network Length (km)", ]
      if (nrow(delta_row) > 0 && !is.na(delta_row$Delta[1])) sprintf("%.2f km", abs(delta_row$Delta[1])) else "--"
    })

    output$table_closed_edges <- shiny::renderTable({
      net <- current_net()
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      if (length(sel) == 0 || is.null(net)) {
        return(data.frame(Estado = "No hay tramos seleccionados. Haz clic en el mapa o b\u00fascalos en el buscador superior."))
      }
      valid_sel <- sel[sel >= 1 & sel <= nrow(net$edges)]
      if (length(valid_sel) == 0) {
        return(data.frame(Estado = "Tramos inv\u00e1lidos."))
      }
      sub_edges <- net$edges[valid_sel, , drop = FALSE]
      names_col <- if ("name" %in% names(sub_edges)) {
        v <- sub_edges$name
        ifelse(is.na(v) | v == "", "(Sin nombre)", v)
      } else {
        paste0("Tramo #", valid_sel)
      }
      type_col <- if ("highway" %in% names(sub_edges)) {
        v <- sub_edges$highway
        ifelse(is.na(v), "v\u00eda", v)
      } else {
        "v\u00eda"
      }
      data.frame(
        `# ID` = valid_sel,
        Nombre = names_col,
        Tipo = type_col,
        `Longitud (m)` = round(sub_edges$length_m, 1),
        check.names = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    output$map_scenarios <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      m <- mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control() |>
        mapgl::add_line_layer(
          id = "scen_base_streets",
          source = edges_wgs,
          line_color = "#005F73",
          line_width = 1.8,
          line_opacity = 0.65
        )

      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel) & sel >= 1 & sel <= nrow(edges_wgs)]
      s <- scen_res()

      if (!is.null(s) && length(s$closed_edges) > 0) {
        closed_wgs <- edges_wgs[s$closed_edges, ]
        closed_wgs$tooltip_text <- paste0("Tramo #", s$closed_edges, " [Clausurado]")

        m <- m |>
          mapgl::add_line_layer(
            id = "scen_closed_streets",
            source = closed_wgs,
            line_color = "#AE2012",
            line_width = 4.5,
            line_dasharray = c(2, 2),
            tooltip = "tooltip_text"
          )
      } else if (length(sel) > 0) {
        marked_wgs <- edges_wgs[sel, ]
        marked_wgs$tooltip_text <- paste0("Tramo #", sel, " [Marcado para clausura]")

        m <- m |>
          mapgl::add_line_layer(
            id = "scen_marked_streets",
            source = marked_wgs,
            line_color = "#E76F51",
            line_width = 4,
            tooltip = "tooltip_text"
          )
      }
      m
    })
  }
}

utils::globalVariables(c("streets_cusco", "streets_lima", "streets_arequipa"))
