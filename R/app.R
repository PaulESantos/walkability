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
              processEscapes: true,
              ignoreClass: 'tex2jax_ignore|no-math',
              processClass: 'tex2jax_process'
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
                ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                ignoredClasses: ['tex2jax_ignore', 'no-math', 'shiny-text-output', 'language-r'],
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

          function copyCodeToClipboard() {
            var el = document.getElementById('code_text_display');
            if (!el) return;
            var text = el.innerText || el.textContent;
            if (navigator.clipboard && window.isSecureContext) {
              navigator.clipboard.writeText(text).then(function() {
                if (window.Shiny) Shiny.setInputValue('code_copied_trigger', Math.random());
              });
            } else {
              var textArea = document.createElement('textarea');
              textArea.value = text;
              textArea.style.position = 'fixed';
              textArea.style.left = '-999999px';
              document.body.appendChild(textArea);
              textArea.focus();
              textArea.select();
              try {
                document.execCommand('copy');
                if (window.Shiny) Shiny.setInputValue('code_copied_trigger', Math.random());
              } catch (err) {
                console.error('Error al copiar c\u00f3digo:', err);
              }
              document.body.removeChild(textArea);
            }
          }
        ")),
        shiny::tags$style(shiny::HTML("
          pre#code_text_display,
          #code_text_display {
            background-color: #0f172a !important;
            color: #f8fafc !important;
            border: 1px solid #334155 !important;
            border-radius: 8px !important;
            padding: 18px 20px !important;
            font-family: 'Fira Code', Consolas, Monaco, monospace !important;
            font-size: 0.88rem !important;
            line-height: 1.6 !important;
            max-height: 580px !important;
            overflow-x: auto !important;
            overflow-y: auto !important;
            white-space: pre !important;
            word-break: normal !important;
            word-wrap: normal !important;
            display: block !important;
          }
          pre#code_text_display *,
          #code_text_display * {
            color: #f8fafc !important;
            background-color: transparent !important;
            font-family: inherit !important;
          }
          .accordion-button:not(.collapsed) {
            background-color: #e0f2fe;
            color: #0369a1;
            font-weight: 600;
          }
          .morph-legend-box {
            background: #ffffff;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            padding: 10px 12px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
          }
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
      shiny::downloadButton(
        outputId = "dl_net_edges",
        label = "Descargar Red Activa (GeoJSON)",
        class = "btn-sm btn-outline-secondary w-100 mt-2",
        icon = shiny::icon("download")
      ),
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
          shiny::downloadButton(
            outputId = "dl_reach_sf",
            label = "Descargar Capa Alcance (GeoJSON)",
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
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
          mapgl::maplibreOutput("map_reach", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = "\U0001f4d6 Fundamento Te\u00f3rico y Consideraciones Metodol\u00f3gicas (Desplegar)",
            icon = shiny::icon("circle-info"),
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
          shiny::selectizeInput(
            inputId = "iso_cutoffs",
            label = "Horizontes de tiempo (min):",
            choices = c("3 min" = 3, "5 min" = 5, "10 min" = 10, "15 min" = 15, "20 min" = 20),
            selected = c(5, 10, 15),
            multiple = TRUE,
            options = list(
              create = TRUE,
              placeholder = "Elige o escribe minutos...",
              plugins = list("remove_button")
            )
          ),
          shiny::textInput(
            inputId = "iso_custom_times_text",
            label = "O escribe tiempos libres (min):",
            value = "",
            placeholder = "Ej: 3, 6 o 3, 7, 12 (separados por coma)"
          ),
          shiny::uiOutput("iso_times_preview"),
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
          ),
          shiny::downloadButton(
            outputId = "dl_iso_sf",
            label = "Descargar Is\u00f3cronas (GeoJSON)",
            class = "btn-sm btn-outline-success w-100 mt-2",
            icon = shiny::icon("download")
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Pol\u00edgonos de Is\u00f3cronas (MapLibre GL)"),
          mapgl::maplibreOutput("map_iso", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = "\U0001f4ca Resumen de Cobertura por Banda Temporal (Desplegar)",
            icon = shiny::icon("table"),
            shiny::tableOutput("table_iso_bands")
          ),
          bslib::accordion_panel(
            title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Is\u00f3cronas Multitemporales No Superpuestas",
            icon = shiny::icon("circle-info"),
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
          shiny::downloadButton(
            outputId = "dl_route_sf",
            label = "Descargar Ruta (GeoJSON)",
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
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
          mapgl::maplibreOutput("map_route", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Ruteo Dijkstra y Circuidad Urbana (Desplegar)",
            icon = shiny::icon("circle-info"),
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
      )
    ),

    # 4. PESTA\u00d1A: MORFOLOG\u00cdA Y CRUCES
    bslib::nav_panel(
      title = "\U0001f3d9\ufe0f Morfolog\u00eda Urbana",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "M\u00e9tricas Morfol\u00f3gicas",
          width = 320,
          shiny::checkboxGroupInput(
            inputId = "morph_classes",
            label = "Filtrar cruces en el mapa:",
            choices = c(
              "Cul-de-sacs (1 v\u00eda, callej\u00f3n ciego)" = 1,
              "Cruces en T (3 v\u00edas)" = 3,
              "Cruces en Cuadr\u00edcula (4+ v\u00edas)" = 4
            ),
            selected = c(1, 3, 4)
          ),
          # Leyenda explicativa interactiva
          shiny::tags$div(
            class = "morph-legend-box my-2",
            shiny::tags$h6(style = "font-size: 0.85rem; font-weight: 700; margin-bottom: 8px; color: #005F73;", "Leyenda de Tipolog\u00edas de Cruce:"),
            shiny::tags$div(style = "display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;",
              shiny::tags$span(style = "width: 12px; height: 12px; border-radius: 50%; background-color: #E63946; display: inline-block; margin-right: 8px; flex-shrink: 0;"),
              shiny::tags$span(shiny::tags$strong("Grado 1 (Rojo): "), "Cul-de-sac / Callej\u00f3n ciego")
            ),
            shiny::tags$div(style = "display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;",
              shiny::tags$span(style = "width: 12px; height: 12px; border-radius: 50%; background-color: #457B9D; display: inline-block; margin-right: 8px; flex-shrink: 0;"),
              shiny::tags$span(shiny::tags$strong("Grado 3 (Azul): "), "Cruce en T (3 ramales)")
            ),
            shiny::tags$div(style = "display: flex; align-items: center; font-size: 0.82rem;",
              shiny::tags$span(style = "width: 12px; height: 12px; border-radius: 50%; background-color: #2A9D8F; display: inline-block; margin-right: 8px; flex-shrink: 0;"),
              shiny::tags$span(shiny::tags$strong("Grado 4+ (Verde): "), "Ortogonal / Damero en cruz")
            )
          ),
          shiny::downloadButton(
            outputId = "dl_morph_sf",
            label = "Descargar Nodos (GeoJSON)",
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
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
          mapgl::maplibreOutput("map_morph", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Tipolog\u00eda de Cruces y Conectividad (Desplegar)",
            icon = shiny::icon("circle-info"),
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
      )
    ),

    # 5. PESTA\u00d1A: SIMULACI\u00d3N DE ESCENARIOS E INTERMEDIACI\u00d3N
    bslib::nav_panel(
      title = "\U0001f6a7 Simulaci\u00f3n & Intermediaci\u00f3n",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = "Simulaci\u00f3n e Intermediaci\u00f3n",
          width = 330,
          shiny::radioButtons(
            inputId = "scen_view_mode",
            label = "Capa en Visualizador:",
            choices = c(
              "1. Intermediaci\u00f3n Base (Inicial)" = "base_bw",
              "2. Intermediaci\u00f3n Post-Cierre (Simulaci\u00f3n)" = "sim_bw",
              "3. V\u00edas con Mayor Intermediaci\u00f3n / Desv\u00edos (\u0394)" = "delta_bw"
            ),
            selected = "base_bw"
          ),
          shiny::hr(),
          shiny::sliderInput(
            inputId = "scen_snap_radius",
            label = "Radio para correcci\u00f3n de red (m):",
            min = 0,
            max = 25,
            value = 0,
            step = 1
          ),
          shiny::helpText("Tolerancia para unir discontinuidades y undershoots antes del c\u00e1lculo."),
          shiny::selectInput(
            inputId = "scen_analysis_radius",
            label = "Radio m\u00e9trico de intermediaci\u00f3n:",
            choices = c(
              "Toda la red (Global)" = "0",
              "Radio 400 m (Barrial)" = "400",
              "Radio 800 m (10 min peatonal)" = "800",
              "Radio 1200 m (Sector urbano)" = "1200"
            ),
            selected = "0"
          ),
          shiny::actionButton(
            inputId = "btn_recalc_bw_base",
            label = "Recalcular Intermediaci\u00f3n Base",
            class = "btn-sm btn-outline-primary w-100 mb-2",
            icon = shiny::icon("rotate")
          ),
          shiny::hr(),
          shiny::tags$p(
            style = "font-size: 0.85rem; color: #495057; margin-bottom: 6px; font-weight: 600;",
            "Seleccionar tramos a clausurar / peatonalizar:"
          ),
          shiny::selectizeInput(
            inputId = "scen_edge_select",
            label = NULL,
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
              label = "Al azar",
              class = "btn-sm btn-outline-secondary w-50",
              icon = shiny::icon("shuffle")
            )
          ),
          shiny::actionButton(
            inputId = "btn_pick_top_bottleneck",
            label = "Elegir Cuello de Botella Top",
            class = "btn-sm btn-outline-danger w-100 mb-2",
            icon = shiny::icon("fire")
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
            label = "Simular Cierre e Intermediaci\u00f3n",
            class = "btn-warning w-100 fw-bold",
            icon = shiny::icon("traffic-light")
          ),
          shiny::downloadButton(
            outputId = "dl_betweenness_base_sf",
            label = "Descargar Intermediaci\u00f3n Base (GeoJSON)",
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
          ),
          shiny::downloadButton(
            outputId = "dl_betweenness_sim_sf",
            label = "Descargar Simulaci\u00f3n Cierres (GeoJSON)",
            class = "btn-sm btn-outline-success w-100 mt-1",
            icon = shiny::icon("download")
          ),
          shiny::downloadButton(
            outputId = "dl_scen_sf",
            label = "Descargar Red Modificada (GeoJSON)",
            class = "btn-sm btn-outline-secondary w-100 mt-1",
            icon = shiny::icon("download")
          ),
          shiny::hr(),
          bslib::value_box(
            title = "Cuello de Botella (Base)",
            value = shiny::textOutput("scen_top_base_stat"),
            showcase = shiny::icon("bridge"),
            theme = "primary"
          ),
          bslib::value_box(
            title = "Mayor Desv\u00edo (Simulaci\u00f3n)",
            value = shiny::textOutput("scen_top_sim_stat"),
            showcase = shiny::icon("arrows-split-up-and-left"),
            theme = "danger"
          ),
          bslib::value_box(
            title = "Longitud Suprimida",
            value = shiny::textOutput("scen_closed_len"),
            showcase = shiny::icon("scissors"),
            theme = "secondary"
          ),
          bslib::value_box(
            title = "Intermediaci\u00f3n Media Red",
            value = shiny::textOutput("scen_delta_bw_stat"),
            showcase = shiny::icon("chart-line"),
            theme = "warning"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Centralidad de Intermediaci\u00f3n y Simulaci\u00f3n de Desv\u00edos (MapLibre GL)"),
          mapgl::maplibreOutput("map_scenarios", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = "\U0001f4ca V\u00edas con Mayor Intermediaci\u00f3n Producto del Cierre (Desv\u00edos) (Desplegar)",
            icon = shiny::icon("arrow-trend-up"),
            shiny::tableOutput("table_top_diverted")
          ),
          bslib::accordion_panel(
            title = "\U0001f4cb Detalle de Tramos Seleccionados para la Intervenci\u00f3n (Desplegar)",
            icon = shiny::icon("table-list"),
            shiny::tableOutput("table_closed_edges")
          ),
          bslib::accordion_panel(
            title = "\U0001f4d6 Fundamento Te\u00f3rico: \u00bfQu\u00e9 Mide la Intermediaci\u00f3n? (Desplegar)",
            icon = shiny::icon("circle-info"),
            shiny::HTML("
              <h5>Intermediaci\u00f3n: qu\u00e9 mide</h5>
              <p>La intermediaci\u00f3n mide la proporci\u00f3n de rutas m\u00e1s cortas potenciales que pasan por un tramo. Para cada par de nodos conectados, la herramienta busca la ruta de menor longitud y suma cr\u00e9dito a los tramos que esa ruta utiliza. Un valor alto se\u00f1ala un posible puente, conector o cuello de botella estructural: si se interrumpe, muchas rutas potenciales tendr\u00edan que desviarse.</p>
              <div class=\"alert alert-warning py-2 px-3 my-2 border-start border-4 border-warning\">
                <strong>No es un aforo ni una predicci\u00f3n de congesti\u00f3n.</strong> La herramienta no conoce cu\u00e1ntos veh\u00edculos viajan, sus or\u00edgenes y destinos, horarios, sentidos de circulaci\u00f3n ni velocidades reales. Por ello, un tramo rojo merece revisi\u00f3n como prioridad estructural, pero no debe interpretarse como \u201cla v\u00eda con m\u00e1s tr\u00e1nsito\u201d.
              </div>
              <h6>\u00bfPor qu\u00e9 establecer radios para la correcci\u00f3n de la red?</h6>
              <p>Las redes digitalizadas suelen presentar peque\u00f1as discontinuidades o <em>undershoots</em> (brechas milim\u00e9tricas o m\u00e9tricas entre segmentos adyacentes). El <strong>radio para la correcci\u00f3n de la red</strong> (tolerancia de snapping en metros) une y cicatriza autom\u00e1ticamente estos extremos antes del c\u00e1lculo de rutas m\u00e1s cortas, asegurando que la intermediaci\u00f3n eval\u00fae la permeabilidad real de la trama urbana y no anomal\u00edas de digitalizaci\u00f3n.</p>
              <h6>Din\u00e1mica de Desv\u00edos y Sobrecarga tras el Cierre</h6>
              <p>Al clausurar o peatonalizar los tramos seleccionados, los itinerarios que antes cruzaban por ellos deben desviarse por v\u00edas alternativas. El m\u00f3dulo recalcula la intermediaci\u00f3n de toda la red restante e identifica los tramos con mayor incremento ($\\Delta > 0$), los cuales representan los <strong>corredores que absorber\u00e1n la mayor redistribuci\u00f3n de flujo</strong>.</p>
            ")
          )
        )
      )
    ),

    # 6. PESTA\u00d1A: GU\u00cdA Y GENERADOR DE C\u00d3DIGO R (ESTILO ESQUISSE)
    bslib::nav_panel(
      title = "\U0001f4bb C\u00f3digo R Generativo",
      bslib::card(
        bslib::card_header(
          shiny::div(
            class = "d-flex justify-content-between align-items-center w-100",
            shiny::tags$span(shiny::tags$strong("Generador de C\u00f3digo R Reproducible"), " (Sincronizado en Tiempo Real)"),
            shiny::div(
              class = "d-flex gap-2",
              shiny::actionButton(
                inputId = "btn_copy_code",
                label = "Copiar al Portapapeles",
                icon = shiny::icon("copy"),
                class = "btn-sm btn-outline-primary",
                onclick = "copyCodeToClipboard()"
              ),
              shiny::downloadButton(
                outputId = "dl_code_script",
                label = "Descargar Script (.R)",
                class = "btn-sm btn-outline-secondary",
                icon = shiny::icon("file-arrow-down")
              )
            )
          )
        ),
        shiny::div(
          class = "row mb-3",
          shiny::div(
            class = "col-md-5",
            shiny::selectInput(
              inputId = "code_module_filter",
              label = "Filtrar por M\u00f3dulo / An\u00e1lisis:",
              choices = c(
                "Script Completo Reproducible (End-to-End)" = "all",
                "1. Construcci\u00f3n de Red Vial" = "network",
                "2. Alcance Peatonal (Reach)" = "reach",
                "3. Is\u00f3cronas Multitemporales" = "iso",
                "4. Ruteo \u00d3ptimo & Circuidad" = "route",
                "5. Morfolog\u00eda Urbana & Cruces" = "morph",
                "6. Simulaci\u00f3n de Escenarios" = "scen"
              ),
              selected = "all"
            )
          ),
          shiny::div(
            class = "col-md-7 d-flex align-items-center",
            shiny::tags$p(
              class = "text-muted mb-0",
              style = "font-size: 0.85rem;",
              "Este script refleja exactamente la red activa, los puntos fijados en el mapa, coordenadas y par\u00e1metros seleccionados en la sesi\u00f3n."
            )
          )
        ),
        shiny::div(
          class = "tex2jax_ignore no-math",
          shiny::verbatimTextOutput("code_text_display")
        )
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

    # Download handler for base network
    output$dl_net_edges <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_red_vial_", input$city_choice, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        net <- current_net()
        shiny::req(net, net$edges)
        sf::st_write(sf::st_transform(net$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

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

    # Download handler for Reach sf edges
    output$dl_reach_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_alcance_", input$reach_time_min, "min_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        r <- reach_res()
        if (is.null(r) || is.null(r$edges)) {
          shiny::showNotification("Calcula el alcance antes de descargar.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(r$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

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

    # Reactive helper to resolve active isochrone cutoffs
    active_iso_cutoffs <- shiny::reactive({
      custom_txt <- trimws(input$iso_custom_times_text %||% "")
      if (nzchar(custom_txt)) {
        # Robust regex extracting all numbers (integers or decimals) even if user writes "3 min, 6 min" or "3min, 6min"
        matches <- regmatches(custom_txt, gregexpr("[0-9]+(?:\\.[0-9]+)?", custom_txt))[[1]]
        nums <- as.numeric(matches)
        cutoffs <- sort(unique(nums[!is.na(nums) & nums > 0]))
        if (length(cutoffs) > 0) return(cutoffs)
      }
      cutoffs <- sort(unique(as.numeric(input$iso_cutoffs)))
      if (length(cutoffs) == 0) cutoffs <- c(5, 10, 15)
      cutoffs
    })

    # Real-time preview badge of the active cutoffs to be computed
    output$iso_times_preview <- shiny::renderUI({
      cuts <- active_iso_cutoffs()
      is_custom <- nzchar(trimws(input$iso_custom_times_text %||% ""))
      src_label <- if (is_custom) "Tiempos detectados:" else "Tiempos seleccionados:"
      shiny::tags$div(
        class = "alert alert-info py-1 px-2 my-2",
        style = "font-size: 0.8rem;",
        shiny::tags$strong(src_label), " ",
        shiny::tags$span(style = "font-weight: 700; color: #005F73;", paste0(cuts, " min", collapse = ", "))
      )
    })

    shiny::observe({
      net <- current_net()
      shiny::req(net)
      coords <- iso_origin_coords()

      cutoffs <- active_iso_cutoffs()

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

    # Download handler for Isochrone sf polygons
    output$dl_iso_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_isocronas_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        iso <- iso_res()
        if (is.null(iso) || is.null(iso$polygons)) {
          shiny::showNotification("Genera las is\u00f3cronas antes de descargar.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(iso$polygons, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

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

    # Download handler for Route sf path
    output$dl_route_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_ruta_optima_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        r <- route_res()
        if (is.null(r) || is.null(r$path_sf)) {
          shiny::showNotification("Calcula una ruta entre dos puntos antes de descargar.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(r$path_sf, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

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
        # Red vial original en el fondo con transparencia
        mapgl::add_line_layer(
          id = "route_bg_streets",
          source = edges_wgs,
          line_color = "#475569",
          line_width = 1.8,
          line_opacity = 0.40
        )

      pa <- route_pt_a()
      pb <- route_pt_b()

      if (!is.null(pa)) {
        pt_a_sf <- sf::st_sf(label = "Origen (A)", geometry = sf::st_sfc(sf::st_point(pa), crs = 4326))
        m <- m |> mapgl::add_circle_layer(
          id = "marker_a",
          source = pt_a_sf,
          circle_color = "#10B981",
          circle_radius = 9,
          circle_stroke_width = 2.5,
          circle_stroke_color = "#FFFFFF"
        )
      }

      if (!is.null(pb)) {
        pt_b_sf <- sf::st_sf(label = "Destino (B)", geometry = sf::st_sfc(sf::st_point(pb), crs = 4326))
        m <- m |> mapgl::add_circle_layer(
          id = "marker_b",
          source = pt_b_sf,
          circle_color = "#F97316",
          circle_radius = 9,
          circle_stroke_width = 2.5,
          circle_stroke_color = "#FFFFFF"
        )
      }

      r <- route_res()
      if (!is.null(r) && !is.null(r$path_sf)) {
        path_wgs <- sf::st_transform(r$path_sf, 4326)
        path_wgs$tooltip_text <- sprintf("Ruta: %.1f m | %.1f min | Circuidad: %.2f", r$distance_m, r$time_min, r$circuity)
        
        # Halo de contraste detr\u00e1s de la ruta \u00f3ptima
        m <- m |>
          mapgl::add_line_layer(
            id = "route_path_casing",
            source = path_wgs,
            line_color = "#FFFFFF",
            line_width = 7.5,
            line_opacity = 0.95
          ) |>
          # Trazado principal de la ruta \u00f3ptima sobre la red
          mapgl::add_line_layer(
            id = "route_path",
            source = path_wgs,
            line_color = "#E63946",
            line_width = 5.0,
            line_opacity = 1.0,
            tooltip = "tooltip_text"
          )
      }

      # Leyenda cartogr\u00e1fica de ruteo
      m |> mapgl::add_categorical_legend(
        legend_title = "Ruta & Red Vial",
        values = c("Ruta \u00d3ptima", "Red Vial Base (Fondo)"),
        colors = c("#E63946", "#475569"),
        position = "bottom-right"
      )
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
      val <- if (!is.null(m$summary$intersection_density_km2)) m$summary$intersection_density_km2 else m$intersection_density_km2
      if (is.null(val) || is.na(val)) return("--")
      sprintf("%.1f / km\u00b2", val)
    })

    output$morph_culdesac <- shiny::renderText({
      m <- morph_res()
      if (is.null(m)) return("--")
      val <- if (!is.null(m$summary$cul_de_sac_ratio)) m$summary$cul_de_sac_ratio * 100 else m$cul_de_sac_ratio_pct
      if (is.null(val) || is.na(val)) return("--")
      sprintf("%.1f %%", val)
    })

    output$morph_ortho <- shiny::renderText({
      m <- morph_res()
      if (is.null(m)) return("--")
      val <- if (!is.null(m$summary$grid_4way_ratio)) m$summary$grid_4way_ratio * 100 else m$orthogonality_ratio_pct
      if (is.null(val) || is.na(val)) return("--")
      sprintf("%.1f %%", val)
    })

    # Download handler for Morphology nodes sf
    output$dl_morph_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_morfologia_nodos_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        m_calc <- morph_res()
        if (is.null(m_calc) || is.null(m_calc$nodes)) {
          shiny::showNotification("No hay nodos de morfolog\u00eda calculados.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(m_calc$nodes, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

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

      # Interactive Categorical Legend for morphology classes
      m |> mapgl::add_categorical_legend(
        legend_title = "Tipolog\u00eda de Cruce",
        values = c(
          "Grado 1: Cul-de-sac (Ciego)",
          "Grado 3: Cruce en T (3 v\u00edas)",
          "Grado 4+: Ortogonal (Damero)"
        ),
        colors = c("#E63946", "#457B9D", "#2A9D8F"),
        circular_patches = TRUE,
        position = "bottom-right"
      )
    })

    # -------------------------------------------------------------
    # 6. PESTA\u00d1A: ESCENARIOS E INTERMEDIACI\u00d3N (SCENARIOS & BETWEENNESS)
    # -------------------------------------------------------------
    bw_base_res <- shiny::reactiveVal(NULL)
    bw_sim_res <- shiny::reactiveVal(NULL)
    scen_res <- shiny::reactiveVal(NULL)

    # Function to calculate baseline betweenness
    calc_base_betweenness <- function() {
      net <- current_net()
      shiny::req(net)
      snap_r <- as.numeric(input$scen_snap_radius %||% 0)
      cut_r <- as.numeric(input$scen_analysis_radius %||% 0)
      shiny::withProgress(message = "Calculando intermediaci\u00f3n de red base...", value = 0.3, {
        b <- walk_betweenness(
          network = net,
          snap_tolerance_m = snap_r,
          radius_m = if (cut_r > 0) cut_r else NULL
        )
        shiny::incProgress(0.7, detail = "Finalizado")
        bw_base_res(b)
        bw_sim_res(NULL)
        scen_res(NULL)
      })
    }

    # Automatically compute baseline betweenness on network load
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      calc_base_betweenness()
    }) |> shiny::bindEvent(current_net(), ignoreInit = FALSE)

    # Recalculate baseline when user explicitly requests
    shiny::observeEvent(input$btn_recalc_bw_base, {
      calc_base_betweenness()
      shiny::showNotification("Intermediaci\u00f3n base recalculada con \u00e9xito.", type = "message")
    })

    # Populate edge choices when network or betweenness updates
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      edges <- net$edges
      n_edges <- nrow(edges)
      if (n_edges > 0) {
        b_base <- bw_base_res()
        choices_vec <- as.character(seq_len(n_edges))
        names(choices_vec) <- vapply(seq_len(n_edges), function(i) {
          nm <- if ("name" %in% names(edges) && !is.na(edges$name[i]) && nzchar(trimws(edges$name[i]))) {
            edges$name[i]
          } else {
            paste0("Tramo #", i)
          }
          hw <- if ("highway" %in% names(edges) && !is.na(edges$highway[i])) edges$highway[i] else "calle"
          bw_str <- if (!is.null(b_base) && !is.null(b_base$edges$betweenness[i])) {
            sprintf(" | Intermed: %.0f", b_base$edges$betweenness[i])
          } else {
            ""
          }
          sprintf("%s [#%d | %.0fm | %s%s]", nm, i, edges$length_m[i], hw, bw_str)
        }, character(1))
        curr_selected <- shiny::isolate(input$scen_edge_select)
        shiny::updateSelectizeInput(
          session,
          "scen_edge_select",
          choices = choices_vec,
          selected = curr_selected,
          server = TRUE
        )
      }
    })

    # Map click: toggle street selection
    shiny::observeEvent(input$map_scenarios_click, {
      clk <- input$map_scenarios_click
      shiny::req(clk, clk$lng, clk$lat)
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)

      pt <- sf::st_sfc(sf::st_point(c(clk$lng, clk$lat)), crs = 4326)
      near_idx <- sf::st_nearest_feature(pt, edges_wgs)
      if (length(near_idx) == 1 && !is.na(near_idx)) {
        curr <- as.character(input$scen_edge_select %||% character(0))
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
      bw_sim_res(NULL)
      scen_res(NULL)
      shiny::updateRadioButtons(session, "scen_view_mode", selected = "base_bw")
    })

    # Pick top bottleneck button
    shiny::observeEvent(input$btn_pick_top_bottleneck, {
      b <- bw_base_res()
      shiny::req(b)
      if (nrow(b$top_bottlenecks) > 0) {
        top_id <- as.character(b$top_bottlenecks$`# ID`[1])
        curr <- as.character(input$scen_edge_select %||% character(0))
        new_sel <- unique(c(curr, top_id))
        shiny::updateSelectizeInput(session, "scen_edge_select", selected = new_sel)
        shiny::showNotification(
          sprintf("Se seleccion\u00f3 el cuello de botella cr\u00edtico #%s (%s)", top_id, b$top_bottlenecks$Nombre[1]),
          type = "message"
        )
      }
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
          "Ning\u00fan tramo seleccionado. Haz clic en el mapa o b\u00fascalo arriba."
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
      snap_r <- as.numeric(input$scen_snap_radius %||% 0)
      cut_r <- as.numeric(input$scen_analysis_radius %||% 0)
      shiny::withProgress(message = "Simulando cierres viales...", value = 0.2, {
        shiny::incProgress(0.3, detail = "Recalculando rutas y redistribuci\u00f3n de intermediaci\u00f3n...")
        sim <- walk_scenario_betweenness(
          network = net,
          closed_edges = valid_edges,
          snap_tolerance_m = snap_r,
          radius_m = if (cut_r > 0) cut_r else NULL,
          verbose = FALSE
        )
        bw_sim_res(sim)
        shiny::incProgress(0.3, detail = "Evaluando variaci\u00f3n de accesibilidad peatonal...")
        mod_net <- sim$mod_network
        comp <- walk_compare_scenarios(base = net, scenario = mod_net, time_min = 5.0, verbose = FALSE)
        scen_res(list(comp = comp, closed_edges = valid_edges, mod_net = mod_net))
        shiny::updateRadioButtons(session, "scen_view_mode", selected = "sim_bw")
        shiny::incProgress(0.2, detail = "Listo")
      })
    })

    # Download handler for Baseline Betweenness GeoJSON
    output$dl_betweenness_base_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_intermediacion_base_", input$city_choice, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        b <- bw_base_res()
        if (is.null(b) || is.null(b$edges)) {
          shiny::showNotification("No hay an\u00e1lisis de intermediaci\u00f3n base disponible.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(b$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # Download handler for Simulation Betweenness GeoJSON
    output$dl_betweenness_sim_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_simulacion_intermediacion_cierres_", input$city_choice, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        s <- bw_sim_res()
        if (is.null(s) || is.null(s$edges)) {
          shiny::showNotification("Simula una intervenci\u00f3n antes de descargar los resultados de intermediaci\u00f3n.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(s$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # Download handler for Scenarios modified network sf
    output$dl_scen_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("walkability_escenario_red_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        s <- scen_res()
        if (is.null(s) || is.null(s$mod_net)) {
          shiny::showNotification("Simula una intervenci\u00f3n antes de descargar la red resultante.", type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(s$mod_net$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # Value boxes
    output$scen_top_base_stat <- shiny::renderText({
      b <- bw_base_res()
      if (is.null(b) || nrow(b$top_bottlenecks) == 0) return("--")
      top_row <- b$top_bottlenecks[1, ]
      sprintf("%s [#%s | %.0f]", top_row$Nombre, top_row$`# ID`, top_row$Intermediacion)
    })

    output$scen_top_sim_stat <- shiny::renderText({
      s <- bw_sim_res()
      if (is.null(s) || nrow(s$top_diverted) == 0) return("--")
      top_row <- s$top_diverted[1, ]
      sprintf("%s [#%s | \u0394 %+.0f]", top_row$Nombre, top_row$`# ID`, top_row$`Incremento (Delta)`)
    })

    output$scen_closed_len <- shiny::renderText({
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      net <- current_net()
      if (length(sel) == 0 || is.null(net)) return("0.0 m")
      valid_sel <- sel[sel >= 1 & sel <= nrow(net$edges)]
      tot_m <- sum(net$edges$length_m[valid_sel], na.rm = TRUE)
      if (tot_m >= 1000) sprintf("%.2f km", tot_m / 1000) else sprintf("%.1f m", tot_m)
    })

    output$scen_delta_bw_stat <- shiny::renderText({
      s <- bw_sim_res()
      if (is.null(s)) {
        b <- bw_base_res()
        if (is.null(b)) return("--")
        sprintf("%.0f (media base)", b$summary$mean_betweenness)
      } else {
        sprintf("%.0f \u2192 %.0f", s$summary$base_mean, s$summary$sim_mean)
      }
    })

    # Tables
    output$table_top_diverted <- shiny::renderTable({
      s <- bw_sim_res()
      if (is.null(s) || nrow(s$top_diverted) == 0) {
        return(data.frame(Estado = "Ejecuta una simulaci\u00f3n para identificar qu\u00e9 v\u00edas asumen mayor intermediaci\u00f3n producto del cierre."))
      }
      s$top_diverted
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

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
      b_base <- bw_base_res()
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
      bw_col <- if (!is.null(b_base) && !is.null(b_base$edges$betweenness)) {
        round(b_base$edges$betweenness[valid_sel], 1)
      } else {
        rep(NA_real_, length(valid_sel))
      }
      data.frame(
        `# ID` = valid_sel,
        Nombre = names_col,
        Tipo = type_col,
        `Longitud (m)` = round(sub_edges$length_m, 1),
        `Intermed. Base` = bw_col,
        check.names = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    # Render MapLibre map for Scenarios
    output$map_scenarios <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)

      mode <- input$scen_view_mode %||% "base_bw"
      b_base <- bw_base_res()
      b_sim <- bw_sim_res()

      m <- mapgl::maplibre(
        style = mapgl::carto_style("positron"),
        bounds = bb
      ) |>
        mapgl::add_navigation_control() |>
        mapgl::add_scale_control()

      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel) & sel >= 1 & sel <= nrow(edges_wgs)]

      if (mode == "base_bw" || is.null(b_sim)) {
        # Visualizing baseline betweenness
        if (!is.null(b_base)) {
          b_edges_wgs <- sf::st_transform(b_base$edges, 4326)
          b_edges_wgs$tooltip_text <- sprintf(
            "<strong>%s</strong> [#%s]<br>Tipo: %s | Longitud: %.1fm<br>Intermediaci\u00f3n: %.0f (Norm: %.1f)<br>Percentil: %.1f%% (%s)<br><em>Haz clic para marcar o desmarcar para cierre</em>",
            if ("name" %in% names(b_edges_wgs)) ifelse(is.na(b_edges_wgs$name) | b_edges_wgs$name == "", "(Sin nombre)", b_edges_wgs$name) else paste0("Tramo #", b_edges_wgs$edge_id),
            b_edges_wgs$edge_id,
            if ("highway" %in% names(b_edges_wgs)) ifelse(is.na(b_edges_wgs$highway), "calle", b_edges_wgs$highway) else "calle",
            b_edges_wgs$length_m,
            b_edges_wgs$betweenness,
            b_edges_wgs$betweenness_norm,
            b_edges_wgs$betweenness_pctl,
            b_edges_wgs$bottleneck_class
          )

          m <- m |>
            mapgl::add_line_layer(
              id = "scen_base_bw_streets",
              source = b_edges_wgs,
              line_color = mapgl::get_column("color"),
              line_width = 3.0,
              line_opacity = 0.85,
              tooltip = "tooltip_text"
            )
        } else {
          m <- m |>
            mapgl::add_line_layer(
              id = "scen_default_streets",
              source = edges_wgs,
              line_color = "#005F73",
              line_width = 2.0,
              line_opacity = 0.7
            )
        }

        # Highlight marked edges for closure
        if (length(sel) > 0) {
          marked_wgs <- edges_wgs[sel, ]
          marked_wgs$tooltip_text <- paste0("Tramo #", sel, " [Marcado para clausura]")
          m <- m |>
            mapgl::add_line_layer(
              id = "scen_marked_streets",
              source = marked_wgs,
              line_color = "#111827",
              line_width = 5.0,
              line_dasharray = c(2, 2),
              tooltip = "tooltip_text"
            )
        }

        m <- m |> mapgl::add_categorical_legend(
          legend_title = "Intermediaci\u00f3n Base (Cuellos de Botella)",
          values = c(
            "Cr\u00edtico (Top 10% - Cuello de Botella)",
            "Alto (Top 25% - Conector Principal)",
            "Medio (Conector Secundario)",
            "Bajo (Tr\u00e1fico Local / Capilar)",
            "Marcado para Clausura"
          ),
          colors = c("#D90429", "#F77F00", "#FCBF49", "#457B9D", "#111827"),
          circular_patches = FALSE,
          position = "bottom-right"
        )

      } else if (mode == "sim_bw") {
        # Visualizing simulation post-closure betweenness
        sim_edges_wgs <- sf::st_transform(b_sim$edges, 4326)
        open_wgs <- sim_edges_wgs[!sim_edges_wgs$is_closed, ]
        closed_wgs <- sim_edges_wgs[sim_edges_wgs$is_closed, ]

        open_wgs$tooltip_text <- sprintf(
          "<strong>%s</strong> [#%s]<br>Tipo: %s | Longitud: %.1fm<br>Intermediaci\u00f3n Post-Cierre: %.0f (Norm: %.1f)<br>Base: %.0f (\u0394: %+.0f)<br>Estado: %s",
          if ("name" %in% names(open_wgs)) ifelse(is.na(open_wgs$name) | open_wgs$name == "", "(Sin nombre)", open_wgs$name) else paste0("Tramo #", open_wgs$edge_id),
          open_wgs$edge_id,
          if ("highway" %in% names(open_wgs)) ifelse(is.na(open_wgs$highway), "calle", open_wgs$highway) else "calle",
          open_wgs$length_m,
          open_wgs$betweenness_sim,
          open_wgs$betweenness_sim_norm,
          open_wgs$betweenness_base,
          open_wgs$delta_betweenness,
          open_wgs$status
        )

        m <- m |>
          mapgl::add_line_layer(
            id = "scen_sim_open_streets",
            source = open_wgs,
            line_color = mapgl::get_column("color_sim"),
            line_width = 3.2,
            line_opacity = 0.9,
            tooltip = "tooltip_text"
          )

        if (nrow(closed_wgs) > 0) {
          closed_wgs$tooltip_text <- paste0("Tramo #", closed_wgs$edge_id, " [Clausurado / Peatonalizado]")
          m <- m |>
            mapgl::add_line_layer(
              id = "scen_sim_closed_streets",
              source = closed_wgs,
              line_color = "#111827",
              line_width = 4.5,
              line_dasharray = c(2, 2),
              tooltip = "tooltip_text"
            )
        }

        m <- m |> mapgl::add_categorical_legend(
          legend_title = "Intermediaci\u00f3n Post-Cierre",
          values = c(
            "Cr\u00edtico Post-Cierre (Top 10%)",
            "Alto Post-Cierre (Top 25%)",
            "Medio Post-Cierre",
            "Bajo Post-Cierre",
            "Clausurado / Peatonalizado"
          ),
          colors = c("#D90429", "#F77F00", "#FCBF49", "#457B9D", "#111827"),
          circular_patches = FALSE,
          position = "bottom-right"
        )

      } else {
        # Visualizing delta betweenness (diversions and stress shifts)
        sim_edges_wgs <- sf::st_transform(b_sim$edges, 4326)
        open_wgs <- sim_edges_wgs[!sim_edges_wgs$is_closed, ]
        closed_wgs <- sim_edges_wgs[sim_edges_wgs$is_closed, ]

        open_wgs$tooltip_text <- sprintf(
          "<strong>%s</strong> [#%s]<br>Variaci\u00f3n de Flujo (\u0394): %+.0f<br>Base: %.0f \u2192 Post-Cierre: %.0f<br>Estado: %s",
          if ("name" %in% names(open_wgs)) ifelse(is.na(open_wgs$name) | open_wgs$name == "", "(Sin nombre)", open_wgs$name) else paste0("Tramo #", open_wgs$edge_id),
          open_wgs$edge_id,
          open_wgs$delta_betweenness,
          open_wgs$betweenness_base,
          open_wgs$delta_betweenness + open_wgs$betweenness_base,
          open_wgs$status
        )

        m <- m |>
          mapgl::add_line_layer(
            id = "scen_delta_open_streets",
            source = open_wgs,
            line_color = mapgl::get_column("color_delta"),
            line_width = 3.5,
            line_opacity = 0.9,
            tooltip = "tooltip_text"
          )

        if (nrow(closed_wgs) > 0) {
          closed_wgs$tooltip_text <- paste0("Tramo #", closed_wgs$edge_id, " [Clausurado / Peatonalizado]")
          m <- m |>
            mapgl::add_line_layer(
              id = "scen_delta_closed_streets",
              source = closed_wgs,
              line_color = "#111827",
              line_width = 4.5,
              line_dasharray = c(2, 2),
              tooltip = "tooltip_text"
            )
        }

        m <- m |> mapgl::add_categorical_legend(
          legend_title = "Variaci\u00f3n de Intermediaci\u00f3n (\u0394 Desv\u00edos)",
          values = c(
            "Fuerte Aumento (\u0394 Desv\u00edo Cr\u00edtico)",
            "Aumento Moderado",
            "Neutro / Sin Cambio",
            "Reducci\u00f3n (\u0394 Aliviado)",
            "Clausurado"
          ),
          colors = c("#D90429", "#F77F00", "#94A3B8", "#2A9D8F", "#111827"),
          circular_patches = FALSE,
          position = "bottom-right"
        )
      }

      m
    })

    # -------------------------------------------------------------
    # 7. GENERADOR DE C\u00d3DIGO R REPRODUCIBLE (ESTILO ESQUISSE)
    # -------------------------------------------------------------
    shiny::observeEvent(input$code_copied_trigger, {
      shiny::showNotification("\u00a1C\u00f3digo R copiado al portapapeles con \u00e9xito!", type = "message", duration = 3)
    })

    generated_code_reactive <- shiny::reactive({
      city <- input$city_choice
      spd <- input$param_speed
      rep <- if (isTRUE(input$param_repair)) "TRUE" else "FALSE"
      filt <- input$code_module_filter

      header_txt <- c(
        "# ====================================================================",
        "# An\u00e1lisis de Transitabilidad Peatonal con el Paquete {walkability}",
        "# Script reproducible generado autom\u00e1ticamente por la aplicaci\u00f3n",
        paste0("# Fecha de generaci\u00f3n: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        "# ====================================================================",
        "",
        "library(walkability)",
        "library(sf)",
        ""
      )

      # 1. Red
      net_code <- c(
        "# --- 1. Construcci\u00f3n y Reparaci\u00f3n Topol\u00f3gica de la Red Vial ---"
      )
      if (city == "custom") {
        net_code <- c(net_code,
          "# Sustituye la ruta por tu archivo espacial (.gpkg, .geojson, etc.):",
          "datos_calles <- sf::st_read('ruta/a/tu/archivo_calles.gpkg')",
          sprintf("net <- walk_build_network(datos_calles, walk_speed_kmh = %.1f, repair = %s)", spd, rep)
        )
      } else {
        ds_name <- paste0("streets_", city)
        net_code <- c(net_code,
          sprintf("utils::data(%s, package = 'walkability')", ds_name),
          sprintf("net <- walk_build_network(%s, walk_speed_kmh = %.1f, repair = %s)", ds_name, spd, rep)
        )
      }
      net_code <- c(net_code, "print(net)", "")

      # 2. Reach
      t_reach <- input$reach_time_min
      if (is.null(t_reach)) t_reach <- 10
      reach_code <- c(
        "# --- 2. Alcance Peatonal (10-min Reach / Rust Multi-hilo) ---",
        sprintf("reach <- walk_compute_reach(net, time_min = %.1f)", t_reach),
        "print(reach)",
        "plot(reach)",
        "# sf::st_write(reach$edges, 'red_alcance_peatonal.geojson', delete_dsn = TRUE)",
        ""
      )

      # 3. Isochrones
      iso_orig <- iso_origin_coords()
      custom_txt <- trimws(input$iso_custom_times_text %||% "")
      if (nzchar(custom_txt)) {
        matches <- regmatches(custom_txt, gregexpr("[0-9]+(?:\\.[0-9]+)?", custom_txt))[[1]]
        nums <- as.numeric(matches)
        cutoffs_vec <- sort(unique(nums[!is.na(nums) & nums > 0]))
        if (length(cutoffs_vec) == 0) cutoffs_vec <- sort(unique(as.numeric(input$iso_cutoffs)))
      } else {
        cutoffs_vec <- sort(unique(as.numeric(input$iso_cutoffs)))
      }
      if (length(cutoffs_vec) == 0) cutoffs_vec <- c(5, 10, 15)
      cutoffs_str <- paste(cutoffs_vec, collapse = ", ")
      method_str <- if (!is.null(input$iso_method)) input$iso_method else "concave"
      rings_str <- if (isTRUE(input$iso_rings)) "TRUE" else "FALSE"

      if (is.null(iso_orig)) {
        iso_orig_line <- "origen_coord <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]"
      } else {
        iso_orig_line <- sprintf("origen_coord <- c(%.6f, %.6f)  # Coordenada fijada en mapa", iso_orig[1], iso_orig[2])
      }

      iso_code <- c(
        "# --- 3. Is\u00f3cronas Multitemporales (Anillos No Superpuestos) ---",
        iso_orig_line,
        "origen_sf <- sf::st_sfc(sf::st_point(origen_coord), crs = 4326)",
        "origen_proj <- sf::st_transform(origen_sf, sf::st_crs(net$nodes))",
        sprintf("iso <- walk_isochrone(net, origin = sf::st_coordinates(origen_proj)[1, 1:2], time_min = c(%s), method = '%s', rings = %s)",
                cutoffs_str, method_str, rings_str),
        "print(iso)",
        "plot(iso)",
        "# sf::st_write(iso$polygons, 'isocronas_multitemporales.geojson', delete_dsn = TRUE)",
        ""
      )

      # 4. Route
      pa <- route_pt_a()
      pb <- route_pt_b()
      if (is.null(pa) || is.null(pb)) {
        route_setup <- c(
          "coords_giant <- sf::st_coordinates(sf::st_transform(net$nodes[net$nodes$is_giant, ], 4326))",
          "punto_a <- coords_giant[1, 1:2]",
          "punto_b <- coords_giant[min(50, nrow(coords_giant)), 1:2]"
        )
      } else {
        route_setup <- c(
          sprintf("punto_a <- c(%.6f, %.6f)  # Origen", pa[1], pa[2]),
          sprintf("punto_b <- c(%.6f, %.6f)  # Destino", pb[1], pb[2])
        )
      }
      route_code <- c(
        "# --- 4. Ruteo Punto a Punto y Ratio de Circuidad (Dijkstra Min-Heap) ---",
        route_setup,
        "pt_a_proj <- sf::st_transform(sf::st_sfc(sf::st_point(punto_a), crs = 4326), sf::st_crs(net$nodes))",
        "pt_b_proj <- sf::st_transform(sf::st_sfc(sf::st_point(punto_b), crs = 4326), sf::st_crs(net$nodes))",
        "ruta <- walk_shortest_path(net, from = sf::st_coordinates(pt_a_proj)[1, 1:2], to = sf::st_coordinates(pt_b_proj)[1, 1:2])",
        "print(ruta)",
        "plot(ruta, network = net)",
        "# sf::st_write(ruta$path_sf, 'ruta_optima_caminata.geojson', delete_dsn = TRUE)",
        ""
      )

      # 5. Morphology
      classes_vec <- paste(input$morph_classes, collapse = ", ")
      if (!nzchar(classes_vec)) classes_vec <- "1, 3, 4"
      morph_code <- c(
        "# --- 5. Morfolog\u00eda Urbana y Densidad de Cruces (Topolog\u00eda de Nodos) ---",
        "morfologia <- walk_intersection_density(net)",
        "print(morfologia)",
        "plot(morfologia)",
        sprintf("# Filtrar por clases seleccionadas (grados %s):", classes_vec),
        sprintf("nodos_sel <- morfologia$nodes[morfologia$nodes$degree %%in%% c(%s), ]", classes_vec),
        "# sf::st_write(nodos_sel, 'nodos_morfologia_urbana.geojson', delete_dsn = TRUE)",
        ""
      )

      # 6. Scenarios and Betweenness Centrality
      sel_edges <- as.integer(input$scen_edge_select)
      sel_edges <- sel_edges[!is.na(sel_edges)]
      if (length(sel_edges) == 0) {
        sel_edges_str <- "c(5, 10)"
      } else {
        sel_edges_str <- paste0("c(", paste(sel_edges, collapse = ", "), ")")
      }
      snap_val <- as.numeric(input$scen_snap_radius %||% 0)
      cut_val <- as.numeric(input$scen_analysis_radius %||% 0)
      cut_str <- if (cut_val > 0) paste0(", radius_m = ", cut_val) else ""

      scen_code <- c(
        "# --- 6. Centralidad de Intermediaci\u00f3n (Betweenness) y Simulaci\u00f3n de Cierres ---",
        sprintf("intermediacion_base <- walk_betweenness(net, snap_tolerance_m = %s%s)", snap_val, cut_str),
        "print(intermediacion_base)",
        "plot(intermediacion_base)",
        "",
        "# Simulaci\u00f3n de intervenci\u00f3n y desv\u00edos resultantes:",
        sprintf("tramos_clausura <- %s", sel_edges_str),
        sprintf("simulacion <- walk_scenario_betweenness(net, closed_edges = tramos_clausura, snap_tolerance_m = %s%s)", snap_val, cut_str),
        "print(simulacion)",
        "# V\u00edas que asumen mayor intermediaci\u00f3n producto del cierre:",
        "head(simulacion$top_diverted, 5)",
        "# sf::st_write(intermediacion_base$edges, 'intermediacion_base.geojson', delete_dsn = TRUE)",
        "# sf::st_write(simulacion$edges, 'simulacion_intermediacion_cierres.geojson', delete_dsn = TRUE)",
        ""
      )

      content_map <- list(
        all = c(header_txt, net_code, reach_code, iso_code, route_code, morph_code, scen_code),
        network = c(header_txt, net_code),
        reach = c(header_txt, net_code, reach_code),
        iso = c(header_txt, net_code, iso_code),
        route = c(header_txt, net_code, route_code),
        morph = c(header_txt, net_code, morph_code),
        scen = c(header_txt, net_code, scen_code)
      )

      chosen_filter <- if (!is.null(filt)) filt else "all"
      res_lines <- content_map[[chosen_filter]]
      if (is.null(res_lines)) res_lines <- content_map$all
      paste(res_lines, collapse = "\n")
    })

    output$code_text_display <- shiny::renderText({
      generated_code_reactive()
    })

    output$dl_code_script <- shiny::downloadHandler(
      filename = function() {
        paste0("analisis_walkability_", input$city_choice, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".R")
      },
      content = function(file) {
        cat(generated_code_reactive(), file = file)
      }
    )
  }
}

utils::globalVariables(c("streets_cusco", "streets_lima", "streets_arequipa"))
