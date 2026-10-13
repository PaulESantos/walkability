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
#' @param lang Character string specifying the initial interface language:
#'   `"es"` for Spanish (default) or `"en"` for English. The user can also toggle
#'   the language interactively at runtime via the navbar selector.
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return Runs the Shiny application (returns invisible `NULL`).
#' @name walk_app
#' @export
#'
#' @examples
#' \dontrun{
#' # Launch with default language (Spanish):
#' walk_app()
#'
#' # Launch in English:
#' walk_app(lang = "en")
#'
#' # Launch with a pre-built network:
#' utils::data(streets_cusco)
#' net <- walk_build_network(streets_cusco, verbose = FALSE)
#' walk_app(net, lang = "es")
#' }
walk_app <- function(network = NULL,
                     host = "127.0.0.1",
                     port = NULL,
                     launch.browser = TRUE,
                     lang = c("es", "en"),
                     ...) {
  lang <- match.arg(lang)
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort("The {.pkg shiny} package is required to launch the interactive app. Install with {.code install.packages('shiny')}.")
  }
  if (!requireNamespace("bslib", quietly = TRUE)) {
    cli::cli_abort("The {.pkg bslib} package is required to render the application interface. Install with {.code install.packages('bslib')}.")
  }
  if (!requireNamespace("mapgl", quietly = TRUE)) {
    cli::cli_abort("The {.pkg mapgl} package is required for MapLibre GPU vector rendering. Install with {.code install.packages('mapgl')}.")
  }

  app_ui <- .create_walk_app_ui(has_initial_net = !is.null(network), initial_lang = lang)
  app_server <- .create_walk_app_server(initial_network = network, initial_lang = lang)

  # Support uploading larger spatial files (e.g. up to 250 MB)
  old_opts <- options(shiny.maxRequestSize = 250 * 1024^2)
  on.exit(options(old_opts), add = TRUE)

  app <- shiny::shinyApp(ui = app_ui, server = app_server)
  shiny::runApp(app, host = host, port = port, launch.browser = launch.browser, ...)
}

# ------------------------------------------------------------------------------
# Bilingual Application Dictionaries & Helper Functions
# ------------------------------------------------------------------------------
.app_translations <- list(
  es = list(
    # Brand / Nav
    nav_brand_title = "walkability",
    nav_subtitle = "| Transitabilidad Urbana & An\u00e1lisis de Grafos",
    lang_selector_label = "Idioma / Language:",

    # Tabs
    tab_reach = "\U0001f6b6 Alcance Peatonal (Reach)",
    tab_iso = "\u23f1\ufe0f Is\u00f3cronas Multitemporales",
    tab_route = "\U0001f9ed Ruteo & Circuidad",
    tab_morph = "\U0001f3d9\ufe0f Morfolog\u00eda Urbana",
    tab_scen = "\U0001f6a7 Simulaci\u00f3n & Intermediaci\u00f3n",
    tab_code = "\U0001f4bb C\u00f3digo R Generativo",

    # Sidebar Network
    sidebar_net_title = "Configuraci\u00f3n de Red",
    city_choice_label = "Seleccionar Red Urbana:",
    city_cusco = "Cusco (Centro Hist\u00f3rico)",
    city_lima = "Lima (Damero de Pizarro)",
    city_arequipa = "Arequipa (Yanahuara / Centro)",
    city_custom = "Cargar GeoPackage / Shapefile propio",
    user_file_label = "Subir archivo espacial (.gpkg, .zip, .geojson, .shp):",
    custom_crs_label = "Sistema de Coordenadas (CRS):",
    custom_crs_placeholder = "auto o c\u00f3digo EPSG (ej: 32719, 32618)",
    custom_crs_help = "'auto' proyecta autom\u00e1ticamente a la zona UTM m\u00e9trica adecuada.",
    param_speed_label = "Velocidad de caminata (km/h):",
    param_repair_label = "Reparar topolog\u00eda de red (GIS)",
    param_planarize_label = "Planarizar intersecciones (dividir cruces)",
    param_snap_tol_label = "Tolerancia de snap (metros):",
    param_snap_tol_help = "Corta calles en cruces y une extremos con huecos < tolerancia.",
    param_components_label = "Componentes de red:",
    comp_all = "Todos los segmentos (conservar red GIS completa)",
    comp_largest = "Solo componente continuo principal (islas excluidas)",
    dl_net_edges_label = "Descargar Red Activa (GeoJSON)",
    sidebar_footer_rust = "Motor Rust multi-hilo compilado con Rayon.",
    sidebar_footer_mapgl = "Renderizado cartogr\u00e1fico acelerado por GPU con MapLibre GL v\u00eda mapgl.",

    # Reach Tab
    sidebar_reach_title = "Par\u00e1metros de Alcance",
    reach_time_label = "Presupuesto de tiempo (minutos):",
    btn_calc_reach = "Recalcular Alcance",
    dl_reach_sf = "Descargar Capa Alcance (GeoJSON)",
    box_reach_mean = "Alcance Promedio",
    box_reach_max = "Alcance M\u00e1ximo",
    card_reach_header = "Mapa de Longitud de Red Accesible (MapLibre GL)",
    reach_legend_continuous = "Red Accesible (%d min)",
    reach_legend_base = "Red Peatonal Base",
    reach_legend_title = "Alcance Peatonal",
    reach_tooltip_calc = "Alcance: %.2f km (Tramo #%d)",
    reach_tooltip_base = "Tramo #%d (%.1f m)",
    reach_doc_title = "\U0001f4d6 Fundamento Te\u00f3rico y Consideraciones Metodol\u00f3gicas (Desplegar)",
    reach_doc_html = "<h5>M\u00e9trica de Red Caminable en $X$ Minutos (10-Minute Walk Reach)</h5><p>Esta m\u00e9trica cuantifica la <strong>longitud total de calles f\u00edsicamente alcanzables</strong> a pie desde cada cruce o esquina de la ciudad dentro de un horizonte temporal determinado (por defecto <strong>10 minutos</strong>, aproximadamente 750 metros a una velocidad de dise\u00f1o de 4.5 km/h).</p><h6>\u00bfPor qu\u00e9 es superior al radio euclidiano tradicional?</h6><p>Los an\u00e1lisis urbanos convencionales suelen trazar c\u00edrculos de radio fijo (p. ej., \u00abis\u00f3cronas de \u00e1rea circular de 800 m\u00bb). Este enfoque ignora por completo la morfolog\u00eda del tejido urbano, la presencia de barreras f\u00edsicas (r\u00edos, laderas, avenidas sin cruces) y la estructura de cul-de-sacs. <code>walkability</code> eval\u00faa la conectividad sobre la red real de calles.</p><h6>Regla de Cr\u00e9dito Parcial de Aristas (Rust Kernel)</h6><p>A diferencia de librer\u00edas como <code>osmnx</code> o <code>igraph</code> que descartan o computan completas las aristas donde se agota el tiempo, <code>walkability</code> calcula algebraicamente la fracci\u00f3n exacta alcanzada:</p><div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">$$\\ell_{\\text{frac}} = L_{(u, v)} \\times \\left(\\frac{B - t(u)}{w_{(u, v)}}\\right)$$</div><p>Donde $B$ es el presupuesto de tiempo, $t(u)$ el tiempo acumulado hasta el nodo $u$, $w_{(u, v)}$ el tiempo de cruce del tramo y $L_{(u, v)}$ su longitud f\u00edsica en metros.</p>",

    # Isochrones Tab
    sidebar_iso_title = "Control de Is\u00f3cronas",
    iso_help_click = "Haz clic en cualquier calle del mapa para fijar el centro de origen de las is\u00f3cronas.",
    iso_origin_default = "Origen: Nodo central predeterminado (o haz clic en el mapa)",
    iso_origin_fixed = "Origen fijado en: [%.5f, %.5f]",
    iso_cutoffs_label = "Horizontes de tiempo (min):",
    iso_custom_times_label = "O escribe tiempos libres (min):",
    iso_custom_times_placeholder = "Ej: 3, 6 o 3, 7, 12 (separados por coma)",
    iso_preview_times = "Tiempos a evaluar:",
    iso_rings_label = "Anillos conc\u00e9ntricos no superpuestos (Disjoint Rings)",
    iso_method_label = "M\u00e9todo de envolvente:",
    iso_method_concave = "Envolvente C\u00f3ncava (concave hull)",
    iso_method_buffer = "Buffer de red vial",
    btn_calc_iso = "Generar Is\u00f3cronas",
    dl_iso_sf = "Descargar Is\u00f3cronas (GeoJSON)",
    card_iso_header = "Pol\u00edgonos de Is\u00f3cronas (MapLibre GL)",
    table_iso_bands_title = "\U0001f4ca Resumen de Cobertura por Banda Temporal (Desplegar)",
    table_col_band = "Banda Temporal",
    table_col_cutoff = "L\u00edmite (min)",
    table_col_area_km2 = "\u00c1rea (km\u00b2)",
    table_col_reach_km = "Red Alcanzable (km)",
    table_col_edges = "Tramos",
    iso_doc_title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Is\u00f3cronas Multitemporales No Superpuestas",
    iso_doc_html = "<h5>Tratamiento Topol\u00f3gico de Is\u00f3cronas Conc\u00e9ntricas</h5><p>Cuando se eval\u00faan horizontes temporales m\u00faltiples (por ejemplo, <strong>5, 10 y 15 minutos</strong>), el enfoque convencional genera pol\u00edgonos acumulativos conc\u00e9ntricos donde el pol\u00edgono de 15 minutos cubre completamente a los de 10 y 5 minutos. Esto produce oclusi\u00f3n visual y ambig\u00fcedad m\u00e9trica.</p><h6>Estrategia de Anillos Disjuntos (<em>Donut / Concentric Rings</em>):</h6><p><code>walk_isochrone()</code> implementa una sustracci\u00f3n topol\u00f3gica booleana para garantizar que <strong>los pol\u00edgonos de cada tiempo no se superpongan</strong>:</p><ul><li><strong>Banda 1 (0 \u2013 5 min):</strong> Corresponde a $P_5$.</li><li><strong>Banda 2 (5 \u2013 10 min):</strong> Se calcula como $R_{10} = P_{10} \\setminus P_5$ (<code>st_difference</code>).</li><li><strong>Banda 3 (10 \u2013 15 min):</strong> Se calcula como $R_{15} = P_{15} \\setminus (P_5 \\cup P_{10})$.</li></ul><p>Cada anillo representa un intervalo mutuamente excluyente. Esto permite calcular el \u00e1rea neta y los equipamientos alcanzables espec\u00edficamente en cada salto de 5 minutos, base fundamental para el an\u00e1lisis de la <strong>\u00abCiudad de los 15 minutos\u00bb</strong>.</p>",

    # Routing Tab
    sidebar_route_title = "Ruta Origen-Destino",
    route_mode_label = "Modo de Clic:",
    route_mode_origin = "Fijar Punto A (Origen)",
    route_mode_dest = "Fijar Punto B (Destino)",
    btn_random_route = "Puntos Aleatorios",
    btn_calc_route = "Calcular Ruta \u00d3ptima",
    dl_route_sf = "Descargar Ruta (GeoJSON)",
    box_route_dist = "Distancia en Red",
    box_route_time = "Tiempo Estimado",
    box_route_circuity = "Ratio de Circuidad",
    card_route_header = "Trazado de la Ruta \u00d3ptima (MapLibre GL)",
    route_legend_title = "Ruta & Red Vial",
    route_legend_path = "Ruta \u00d3ptima",
    route_legend_base = "Red Vial Base (Fondo)",
    route_tooltip = "Ruta: %.1f m | %.1f min | Circuidad: %.2f",
    route_doc_title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Ruteo Dijkstra y Circuidad Urbana (Desplegar)",
    route_doc_html = "<h5>Ruteo Punto a Punto y M\u00e9tricas de Desv\u00edo</h5><p>La funci\u00f3n <code>walk_shortest_path()</code> ejecuta una b\u00fasqueda de camino m\u00e1s corto en el motor Rust con parada temprana cuando se extrae el nodo destino del mont\u00edculo binario (<em>Min-Heap</em>).</p><h6>Reconstrucci\u00f3n de Trayectorias y Geometr\u00eda</h6><p>Durante la b\u00fasqueda se mantienen dos arreglos planos <code>prev_node</code> y <code>prev_edge</code>. Una vez alcanzado el destino, el trayecto se reconstruye hacia atr\u00e1s en tiempo $O(\\text{saltos})$ y se extrae la secuencia de geometr\u00edas <code>LINESTRING</code>.</p><h6>Ratio de Circuidad (<em>Route Directness</em>):</h6><div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">$$\\text{Circuity} = \\frac{\\text{Distancia sobre la red vial (m)}}{\\text{Distancia euclidiana en l\u00ednea recta (m)}}$$</div><ul><li><strong>1.0 a 1.2:</strong> Trama directa y permeable con alta eficiencia de desplazamiento peatonal.</li><li><strong>1.2 a 1.4:</strong> Trama moderadamente sinuosa (t\u00edpica de centros coloniales o cuadr\u00edculas con pendientes).</li><li><strong>&gt; 1.5:</strong> Trama discontinua, presencia de cul-de-sacs o barreras f\u00edsicas que obligan al peat\u00f3n a rodeos significativos.</li></ul>",

    # Morphology Tab
    sidebar_morph_title = "M\u00e9tricas Morfol\u00f3gicas",
    morph_classes_label = "Filtrar cruces en el mapa:",
    morph_class_1 = "Cul-de-sacs (1 v\u00eda, callej\u00f3n ciego)",
    morph_class_3 = "Cruces en T (3 v\u00edas)",
    morph_class_4 = "Cruces en Cuadr\u00edcula (4+ v\u00edas)",
    morph_legend_html = "<h6 style=\"font-size: 0.85rem; font-weight: 700; margin-bottom: 8px; color: #005F73;\">Leyenda de Tipolog\u00edas de Cruce:</h6><div style=\"display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #E63946; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Grado 1 (Rojo): </strong>Cul-de-sac / Callej\u00f3n ciego</span></div><div style=\"display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #457B9D; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Grado 3 (Azul): </strong>Cruce en T (3 ramales)</span></div><div style=\"display: flex; align-items: center; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #2A9D8F; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Grado 4+ (Verde): </strong>Ortogonal / Damero en cruz</span></div>",
    dl_morph_sf = "Descargar Nodos (GeoJSON)",
    box_morph_density = "Densidad de Intersecciones",
    box_morph_culdesac = "Proporci\u00f3n de Cul-de-sacs",
    box_morph_ortho = "Ortogonalidad (4 v\u00edas+)",
    card_morph_header = "Tipolog\u00eda de Cruces y Manzanas (MapLibre GL)",
    morph_legend_title = "Tipolog\u00eda de Cruce",
    morph_legend_v1 = "Grado 1: Cul-de-sac (Ciego)",
    morph_legend_v3 = "Grado 3: Cruce en T (3 v\u00edas)",
    morph_legend_v4 = "Grado 4+: Ortogonal (Damero)",
    morph_tooltip = "Tipo: %s (Grado %s)",
    morph_doc_title = "\U0001f4d6 Consideraciones T\u00e9cnicas: Tipolog\u00eda de Cruces y Conectividad (Desplegar)",
    morph_doc_html = "<h5>Clasificaci\u00f3n de Nodos seg\u00fan Valencia Topol\u00f3gica</h5><p>La conectividad de un vecindario se define por la cantidad de alternativas de ruta disponibles para el peat\u00f3n. <code>walk_intersection_density()</code> examina el grado de entrada/salida de cada nodo de la red bidireccional simplificada:</p><ul><li><strong>Grado 1 (Cul-de-sac):</strong> Nodos ciegos que obligan al usuario a retornar por el mismo camino. Un exceso de cul-de-sacs disminuye la transitabilidad activa.</li><li><strong>Grado 2 (V\u00e9rtice de paso):</strong> V\u00e9rtices de curvatura o continuidad que no representan opciones de cruce.</li><li><strong>Grado 3 (Intersecciones en T):</strong> Bifurcaciones regulares de tres ramales.</li><li><strong>Grado 4+ (Cruces ortogonales):</strong> Intersecciones en cruz t\u00edpicas del damero tradicional que maximizan la permeabilidad.</li></ul><h6>Densidad M\u00e9trica sobre la Envolvente Convexa</h6><p>Para evitar el sesgo de \u00e1reas administrativas arbitrarias, la densidad de cruces ($/\\text{km}^2$) se calcula sobre la envolvente convexa (<code>sf::st_convex_hull</code>) de la red analizada.</p>",

    # Scenarios Tab
    sidebar_scen_title = "Simulaci\u00f3n e Intermediaci\u00f3n",
    scen_view_label = "Capa en Visualizador:",
    scen_view_base = "1. Intermediaci\u00f3n Base (Inicial)",
    scen_view_sim = "2. Intermediaci\u00f3n Post-Cierre (Simulaci\u00f3n)",
    scen_view_delta = "3. V\u00edas con Mayor Intermediaci\u00f3n / Desv\u00edos (\u0394)",
    scen_snap_label = "Radio para correcci\u00f3n de red (m):",
    scen_snap_help = "Tolerancia para unir discontinuidades y undershoots antes del c\u00e1lculo.",
    scen_radius_label = "Radio m\u00e9trico de intermediaci\u00f3n:",
    scen_rad_global = "Toda la red (Global)",
    scen_rad_400 = "Radio 400 m (Barrial)",
    scen_rad_800 = "Radio 800 m (10 min peatonal)",
    scen_rad_1200 = "Radio 1200 m (Sector urbano)",
    btn_recalc_bw_base = "Recalcular Intermediaci\u00f3n Base",
    scen_edge_instruction = "Seleccionar tramos a clausurar / peatonalizar:",
    scen_edge_placeholder = "Escribe el nombre de la calle o ID...",
    btn_clear_scen = "Limpiar",
    btn_sample_random = "Al azar",
    btn_pick_top_bottleneck = "Elegir Cuello de Botella Top",
    scen_random_n_label = "Cantidad para muestreo al azar:",
    btn_sim_scenario = "Simular Cierre e Intermediaci\u00f3n",
    dl_bw_base_sf = "Descargar Intermediaci\u00f3n Base (GeoJSON)",
    dl_bw_sim_sf = "Descargar Simulaci\u00f3n Cierres (GeoJSON)",
    dl_scen_sf = "Descargar Red Modificada (GeoJSON)",
    box_scen_bottleneck = "Cuello de Botella (Base)",
    box_scen_diverted = "Mayor Desv\u00edo (Simulaci\u00f3n)",
    box_scen_closed_len = "Longitud Suprimida",
    box_scen_mean_bw = "Intermediaci\u00f3n Media Red",
    card_scen_header = "Centralidad de Intermediaci\u00f3n y Simulaci\u00f3n de Desv\u00edos (MapLibre GL)",
    table_diverted_title = "\U0001f4ca V\u00edas con Mayor Intermediaci\u00f3n Producto del Cierre (Desv\u00edos) (Desplegar)",
    table_closed_title = "\U0001f4cb Detalle de Tramos Seleccionados para la Intervenci\u00f3n (Desplegar)",
    scen_doc_title = "\U0001f4d6 Fundamento Te\u00f3rico: \u00bfQu\u00e9 Mide la Intermediaci\u00f3n? (Desplegar)",
    scen_doc_html = "<h5>Intermediaci\u00f3n: qu\u00e9 mide</h5><p>La intermediaci\u00f3n mide la proporci\u00f3n de rutas m\u00e1s cortas potenciales que pasan por un tramo. Para cada par de nodos conectados, la herramienta busca la ruta de menor longitud y suma cr\u00e9dito a los tramos que esa ruta utiliza. Un valor alto se\u00f1ala un posible puente, conector o cuello de botella estructural: si se interrumpe, muchas rutas potenciales tendr\u00edan que desviarse.</p><div class=\"alert alert-warning py-2 px-3 my-2 border-start border-4 border-warning\"><strong>No es un aforo ni una predicci\u00f3n de congesti\u00f3n.</strong> La herramienta no conoce cu\u00e1ntos veh\u00edculos viajan, sus or\u00edgenes y destinos, horarios, sentidos de circulaci\u00f3n ni velocidades reales. Por ello, un tramo rojo merece revisi\u00f3n como prioridad estructural, pero no debe interpretarse como \u201cla v\u00eda con m\u00e1s tr\u00e1nsito\u201d.</div><h6>\u00bfPor qu\u00e9 establecer radios para la correcci\u00f3n de la red?</h6><p>Las redes digitalizadas suelen presentar peque\u00f1as discontinuidades o <em>undershoots</em> (brechas milim\u00e9tricas o m\u00e9tricas entre segmentos adyacentes). El <strong>radio para la correcci\u00f3n de la red</strong> (tolerancia de snapping en metros) une y cicatriza autom\u00e1ticamente estos extremos antes del c\u00e1lculo de rutas m\u00e1s cortas, asegurando que la intermediaci\u00f3n eval\u00fae la permeabilidad real de la trama urbana y no anomal\u00edas de digitalizaci\u00f3n.</p><h6>Din\u00e1mica de Desv\u00edos y Sobrecarga tras el Cierre</h6><p>Al clausurar o peatonalizar los tramos seleccionados, los itinerarios que antes cruzaban por ellos deben desviarse por v\u00edas alternativas. El m\u00f3dulo recalcula la intermediaci\u00f3n de toda la red restante e identifica los tramos con mayor incremento ($\\Delta > 0$), los cuales representan los <strong>corredores que absorber\u00e1n la mayor redistribuci\u00f3n de flujo</strong>.</p>",

    # Code Generator Tab
    tab_code_header = "Generador de C\u00f3digo R Reproducible",
    tab_code_sync = "(Sincronizado en Tiempo Real)",
    btn_copy_code = "Copiar al Portapapeles",
    dl_code_script = "Descargar Script (.R)",
    code_filter_label = "Filtrar por M\u00f3dulo / An\u00e1lisis:",
    code_filt_all = "Script Completo Reproducible (End-to-End)",
    code_filt_net = "1. Construcci\u00f3n de Red Vial",
    code_filt_reach = "2. Alcance Peatonal (Reach)",
    code_filt_iso = "3. Is\u00f3cronas Multitemporales",
    code_filt_route = "4. Ruteo \u00d3ptimo & Circuidad",
    code_filt_morph = "5. Morfolog\u00eda Urbana & Cruces",
    code_filt_scen = "6. Simulaci\u00f3n de Escenarios",
    code_info_text = "Este script refleja exactamente la red activa, los puntos fijados en el mapa, coordenadas y par\u00e1metros seleccionados en la sesi\u00f3n.",

    # Notifications & Dynamic Feedback
    notif_reach_before_dl = "Calcula el alcance antes de descargar.",
    notif_iso_before_dl = "Genera las is\u00f3cronas antes de descargar.",
    notif_route_before_dl = "Calcula una ruta entre dos puntos antes de descargar.",
    notif_morph_no_nodes = "No hay nodos de morfolog\u00eda calculados.",
    notif_bw_recalc_ok = "Intermediaci\u00f3n base recalculada con \u00e9xito.",
    notif_bw_select_edge = "Por favor selecciona o marca al menos un tramo antes de simular.",
    notif_bw_need_igraph = "El paquete opcional 'igraph' es necesario para simular escenarios de intermediaci\u00f3n.",
    notif_bw_error = "Error en simulaci\u00f3n: %s",
    notif_bw_no_base = "No hay an\u00e1lisis de intermediaci\u00f3n base disponible.",
    notif_bw_sim_before_dl = "Simula una intervenci\u00f3n antes de descargar los resultados de intermediaci\u00f3n.",
    notif_bw_net_before_dl = "Simula una intervenci\u00f3n antes de descargar la red resultante.",
    notif_code_copied = "\u00a1C\u00f3digo R copiado al portapapeles con \u00e9xito!"
  ),

  en = list(
    # Brand / Nav
    nav_brand_title = "walkability",
    nav_subtitle = "| Urban Walkability & Network Graph Analysis",
    lang_selector_label = "Language / Idioma:",

    # Tabs
    tab_reach = "\U0001f6b6 Pedestrian Reach",
    tab_iso = "\u23f1\ufe0f Multi-cutoff Isochrones",
    tab_route = "\U0001f9ed Routing & Circuity",
    tab_morph = "\U0001f3d9\ufe0f Urban Morphology",
    tab_scen = "\U0001f6a7 Simulation & Betweenness",
    tab_code = "\U0001f4bb Reproducible R Code",

    # Sidebar Network
    sidebar_net_title = "Network Configuration",
    city_choice_label = "Select Street Network:",
    city_cusco = "Cusco (Historic Center)",
    city_lima = "Lima (Damero de Pizarro)",
    city_arequipa = "Arequipa (Yanahuara / Center)",
    city_custom = "Upload Custom GeoPackage / Shapefile",
    user_file_label = "Upload spatial dataset (.gpkg, .zip, .geojson, .shp):",
    custom_crs_label = "Coordinate Reference System (CRS):",
    custom_crs_placeholder = "auto or EPSG code (e.g. 32719, 32618)",
    custom_crs_help = "'auto' automatically projects to the appropriate metric UTM zone.",
    param_speed_label = "Walking speed (km/h):",
    param_repair_label = "Repair network topology (GIS)",
    param_planarize_label = "Planarize intersections (split crossings)",
    param_snap_tol_label = "Snap tolerance (meters):",
    param_snap_tol_help = "Splits intersecting lines and snaps endpoints with gaps < tolerance.",
    param_components_label = "Network components:",
    comp_all = "All segments (retain complete GIS network)",
    comp_largest = "Largest connected component only (isolated islands excluded)",
    dl_net_edges_label = "Download Active Network (GeoJSON)",
    sidebar_footer_rust = "Multi-threaded Rust kernel powered by Rayon.",
    sidebar_footer_mapgl = "GPU-accelerated vector cartography with MapLibre GL via mapgl.",

    # Reach Tab
    sidebar_reach_title = "Reach Parameters",
    reach_time_label = "Time budget (minutes):",
    btn_calc_reach = "Recalculate Reach",
    dl_reach_sf = "Download Reach Layer (GeoJSON)",
    box_reach_mean = "Average Reach",
    box_reach_max = "Maximum Reach",
    card_reach_header = "Accessible Network Length Map (MapLibre GL)",
    reach_legend_continuous = "Accessible Network (%d min)",
    reach_legend_base = "Base Pedestrian Network",
    reach_legend_title = "Pedestrian Reach",
    reach_tooltip_calc = "Reach: %.2f km (Segment #%d)",
    reach_tooltip_base = "Segment #%d (%.1f m)",
    reach_doc_title = "\U0001f4d6 Theoretical Foundation & Methodology (Expand)",
    reach_doc_html = "<h5>Accessible Walk Network Metric in $X$ Minutes (10-Minute Walk Reach)</h5><p>This metric quantifies the <strong>total length of streets physically reachable</strong> on foot from every intersection or street corner in the city within a given time budget (by default <strong>10 minutes</strong>, approximately 750 meters at a standard walking speed of 4.5 km/h).</p><h6>Why is it superior to traditional Euclidean radius?</h6><p>Conventional urban analyses typically draw circular buffers (e.g., circular 800-meter isochrones). This approach completely overlooks urban form, topographical barriers (rivers, cliffs, highways without crossings), and cul-de-sacs. <code>walkability</code> assesses connectivity strictly across the actual street network.</p><h6>Partial Edge Credit Rule (Rust Kernel)</h6><p>Unlike packages such as <code>osmnx</code> or <code>igraph</code> that either drop or fully count edges when time expires mid-segment, <code>walkability</code> algebraically computes the exact partial fraction reached:</p><div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">$$\\ell_{\\text{frac}} = L_{(u, v)} \\times \\left(\\frac{B - t(u)}{w_{(u, v)}}\\right)$$</div><p>Where $B$ is the time budget, $t(u)$ is accumulated travel time to node $u$, $w_{(u, v)}$ is the edge traversal time, and $L_{(u, v)}$ is its physical length in meters.</p>",

    # Isochrones Tab
    sidebar_iso_title = "Isochrone Controls",
    iso_help_click = "Click anywhere on the street network to set the isochrone origin center.",
    iso_origin_default = "Origin: Default center node (or click on the map)",
    iso_origin_fixed = "Origin fixed at: [%.5f, %.5f]",
    iso_cutoffs_label = "Time cutoffs (min):",
    iso_custom_times_label = "Or enter custom cutoffs (min):",
    iso_custom_times_placeholder = "e.g. 3, 6 or 3, 7, 12 (comma separated)",
    iso_preview_times = "Cutoffs to evaluate:",
    iso_rings_label = "Non-overlapping concentric rings (Disjoint Rings)",
    iso_method_label = "Hull boundary method:",
    iso_method_concave = "Concave Hull (concave hull)",
    iso_method_buffer = "Street network buffer",
    btn_calc_iso = "Generate Isochrones",
    dl_iso_sf = "Download Isochrones (GeoJSON)",
    card_iso_header = "Isochrone Polygons (MapLibre GL)",
    table_iso_bands_title = "\U0001f4ca Time-Band Coverage Summary (Expand)",
    table_col_band = "Time Band",
    table_col_cutoff = "Cutoff (min)",
    table_col_area_km2 = "Area (km\u00b2)",
    table_col_reach_km = "Accessible Network (km)",
    table_col_edges = "Edges",
    iso_doc_title = "\U0001f4d6 Technical Considerations: Non-Overlapping Isochrones (Expand)",
    iso_doc_html = "<h5>Topological Handling of Concentric Isochrones</h5><p>When evaluating multiple time horizons (for instance, <strong>5, 10, and 15 minutes</strong>), conventional tools generate cumulative concentric polygons where the 15-minute hull fully occludes the 10- and 5-minute hulls. This leads to visual occlusion and metric ambiguity.</p><h6>Disjoint Rings Strategy (<em>Donut / Concentric Rings</em>):</h6><p><code>walk_isochrone()</code> applies boolean topological difference so that <strong>polygons across consecutive cutoffs do not overlap</strong>:</p><ul><li><strong>Band 1 (0 \u2013 5 min):</strong> Corresponds to $P_5$.</li><li><strong>Band 2 (5 \u2013 10 min):</strong> Computed as $R_{10} = P_{10} \\setminus P_5$ (<code>st_difference</code>).</li><li><strong>Band 3 (10 \u2013 15 min):</strong> Computed as $R_{15} = P_{15} \\setminus (P_5 \\cup P_{10})$.</li></ul><p>Each ring represents a mutually exclusive interval, enabling precise calculation of net catchment area and amenities reached within each distinct 5-minute bracket, a foundational concept for <strong>\"15-minute city\"</strong> planning.</p>",

    # Routing Tab
    sidebar_route_title = "Origin-Destination Route",
    route_mode_label = "Click Interaction Mode:",
    route_mode_origin = "Set Point A (Origin)",
    route_mode_dest = "Set Point B (Destination)",
    btn_random_route = "Random Points",
    btn_calc_route = "Compute Optimal Route",
    dl_route_sf = "Download Route (GeoJSON)",
    box_route_dist = "Network Distance",
    box_route_time = "Estimated Travel Time",
    box_route_circuity = "Circuity Ratio",
    card_route_header = "Optimal Path Trace (MapLibre GL)",
    route_legend_title = "Route & Street Network",
    route_legend_path = "Optimal Route",
    route_legend_base = "Base Street Network (Background)",
    route_tooltip = "Route: %.1f m | %.1f min | Circuity: %.2f",
    route_doc_title = "\U0001f4d6 Technical Considerations: Dijkstra Routing & Urban Circuity (Expand)",
    route_doc_html = "<h5>Point-to-Point Routing and Detour Metrics</h5><p>The function <code>walk_shortest_path()</code> executes a shortest path query in the Rust engine with early termination upon popping the target node from the binary Min-Heap.</p><h6>Trajectory and Geometry Reconstruction</h6><p>During the traversal, flat arrays <code>prev_node</code> and <code>prev_edge</code> track predecessor relationships. Once the destination is reached, the route is reconstructed backwards in $O(\\text{hops})$ time to produce the continuous <code>LINESTRING</code> geometry.</p><h6>Circuity Ratio (<em>Route Directness</em>):</h6><div class=\"text-center my-3 p-3 bg-light rounded border fs-5 text-dark\">$$\\text{Circuity} = \\frac{\\text{Network distance along streets (m)}}{\\text{Straight-line Euclidean distance (m)}}$$</div><ul><li><strong>1.0 to 1.2:</strong> Direct, permeable street grid with high pedestrian movement efficiency.</li><li><strong>1.2 to 1.4:</strong> Moderately winding network (typical of historic colonial cores or sloped terrain).</li><li><strong>&gt; 1.5:</strong> Discontinuous grid, heavy presence of cul-de-sacs, or physical barriers requiring significant pedestrian detours.</li></ul>",

    # Morphology Tab
    sidebar_morph_title = "Morphological Metrics",
    morph_classes_label = "Filter intersections on map:",
    morph_class_1 = "Cul-de-sacs (1-way, dead-ends)",
    morph_class_3 = "T-Junctions (3-way branches)",
    morph_class_4 = "Grid Intersections (4+ ways)",
    morph_legend_html = "<h6 style=\"font-size: 0.85rem; font-weight: 700; margin-bottom: 8px; color: #005F73;\">Intersection Typologies Legend:</h6><div style=\"display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #E63946; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Degree 1 (Red): </strong>Cul-de-sac / Dead-end</span></div><div style=\"display: flex; align-items: center; margin-bottom: 6px; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #457B9D; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Degree 3 (Blue): </strong>T-Junction (3 branches)</span></div><div style=\"display: flex; align-items: center; font-size: 0.82rem;\"><span style=\"width: 12px; height: 12px; border-radius: 50%; background-color: #2A9D8F; display: inline-block; margin-right: 8px; flex-shrink: 0;\"></span><span><strong>Degree 4+ (Green): </strong>Orthogonal / 4-way grid</span></div>",
    dl_morph_sf = "Download Nodes (GeoJSON)",
    box_morph_density = "Intersection Density",
    box_morph_culdesac = "Cul-de-sac Proportion",
    box_morph_ortho = "Orthogonality (4-way+)",
    card_morph_header = "Intersection Typology & Blocks (MapLibre GL)",
    morph_legend_title = "Intersection Typology",
    morph_legend_v1 = "Degree 1: Cul-de-sac (Dead-end)",
    morph_legend_v3 = "Degree 3: T-Junction (3 branches)",
    morph_legend_v4 = "Degree 4+: Orthogonal (4-way grid)",
    morph_tooltip = "Type: %s (Degree %s)",
    morph_doc_title = "\U0001f4d6 Technical Considerations: Node Typology & Connectivity (Expand)",
    morph_doc_html = "<h5>Node Classification by Topological Valence</h5><p>Neighborhood connectivity is determined by the number of route choices available to a pedestrian. <code>walk_intersection_density()</code> inspects the degree of each node in the simplified bidirectional graph:</p><ul><li><strong>Degree 1 (Cul-de-sac):</strong> Dead-end nodes forcing users to backtrack. A high cul-de-sac ratio impairs active walkability.</li><li><strong>Degree 2 (Pass-through vertex):</strong> Curvature or intermediate vertices that do not provide crossing decisions.</li><li><strong>Degree 3 (T-Junctions):</strong> 3-way fork intersections.</li><li><strong>Degree 4+ (Orthogonal intersections):</strong> 4-way cross intersections typical of classic street grids that maximize route choice and permeability.</li></ul><h6>Metric Density over Convex Hull</h6><p>To avoid distortions from arbitrary administrative boundaries, intersection density ($/\\text{km}^2$) is computed over the minimum convex hull (<code>sf::st_convex_hull</code>) of the analyzed street network.</p>",

    # Scenarios Tab
    sidebar_scen_title = "Simulation & Betweenness",
    scen_view_label = "Map Layer Display:",
    scen_view_base = "1. Baseline Betweenness (Initial)",
    scen_view_sim = "2. Post-Closure Betweenness (Simulation)",
    scen_view_delta = "3. Streets with Highest Load Shift / Detour (\u0394)",
    scen_snap_label = "Network correction snap radius (m):",
    scen_snap_help = "Tolerance to heal undershoots and gaps prior to routing.",
    scen_radius_label = "Betweenness metric radius:",
    scen_rad_global = "Entire network (Global)",
    scen_rad_400 = "400 m radius (Neighborhood)",
    scen_rad_800 = "800 m radius (10-min walk)",
    scen_rad_1200 = "1200 m radius (Urban district)",
    btn_recalc_bw_base = "Recalculate Base Betweenness",
    scen_edge_instruction = "Select segments to close / pedestrianize:",
    scen_edge_placeholder = "Type street name or ID...",
    btn_clear_scen = "Clear",
    btn_sample_random = "Random",
    btn_pick_top_bottleneck = "Select Top Bottleneck",
    scen_random_n_label = "Sample size for random selection:",
    btn_sim_scenario = "Simulate Closure & Betweenness",
    dl_bw_base_sf = "Download Baseline Betweenness (GeoJSON)",
    dl_bw_sim_sf = "Download Simulated Closures (GeoJSON)",
    dl_scen_sf = "Download Modified Network (GeoJSON)",
    box_scen_bottleneck = "Top Bottleneck (Baseline)",
    box_scen_diverted = "Highest Detour (Simulated)",
    box_scen_closed_len = "Removed Length",
    box_scen_mean_bw = "Mean Network Betweenness",
    card_scen_header = "Betweenness Centrality & Detour Simulation (MapLibre GL)",
    table_diverted_title = "\U0001f4ca Streets with Largest Load Increase (Detours) (Expand)",
    table_closed_title = "\U0001f4cb Intervened Segments Detail (Expand)",
    scen_doc_title = "\U0001f4d6 Theoretical Foundation: What Betweenness Measures (Expand)",
    scen_doc_html = "<h5>Betweenness: What it Measures</h5><p>Betweenness measures the proportion of potential shortest paths passing through a given street segment. For every pair of connected nodes, the algorithm finds the shortest path and adds traversal credits to the traversed edges. A high score marks a structural bridge, connector, or bottleneck: if severed, numerous travel paths must divert.</p><div class=\"alert alert-warning py-2 px-3 my-2 border-start border-4 border-warning\"><strong>This is not a traffic count or congestion forecast.</strong> The tool does not model vehicular counts, origin-destination travel demands, hourly schedules, turn restrictions, or actual driving speeds. A red-colored segment signals structural centrality, not necessarily high traffic volume.</div><h6>Why set network correction snap radii?</h6><p>Digitized street datasets often contain minor gaps or <em>undershoots</em> between adjacent street segments. The <strong>network correction snap radius</strong> (snapping tolerance in meters) automatically heals these disconnected endpoints prior to routing, ensuring betweenness reflects actual urban fabric connectivity rather than digitizing artifacts.</p><h6>Detour Dynamics and Load Redistribution After Closures</h6><p>Upon closing or pedestrianizing selected segments, trips that previously used them must divert to alternate corridors. The module recalculates betweenness across the remaining network and highlights segments with the largest increase ($\\Delta > 0$), identifying the <strong>corridors that will bear the greatest load shift</strong>.</p>",

    # Code Generator Tab
    tab_code_header = "Reproducible R Code Generator",
    tab_code_sync = "(Synchronized in Real Time)",
    btn_copy_code = "Copy to Clipboard",
    dl_code_script = "Download Script (.R)",
    code_filter_label = "Filter by Module / Analysis:",
    code_filt_all = "Complete Reproducible Script (End-to-End)",
    code_filt_net = "1. Street Network Construction",
    code_filt_reach = "2. Pedestrian Reach (10-min Reach)",
    code_filt_iso = "3. Multi-cutoff Isochrones",
    code_filt_route = "4. Optimal Routing & Circuity",
    code_filt_morph = "5. Urban Morphology & Intersections",
    code_filt_scen = "6. Scenario Simulation",
    code_info_text = "This script accurately reflects the active network, map coordinates, and analytical parameters selected in your interactive session.",

    # Notifications & Dynamic Feedback
    notif_reach_before_dl = "Please compute reach before downloading.",
    notif_iso_before_dl = "Please generate isochrones before downloading.",
    notif_route_before_dl = "Please calculate a route between two points before downloading.",
    notif_morph_no_nodes = "No morphological nodes have been computed yet.",
    notif_bw_recalc_ok = "Baseline betweenness successfully recalculated.",
    notif_bw_select_edge = "Please select or check at least one street segment before simulating.",
    notif_bw_need_igraph = "The optional package 'igraph' is required to simulate betweenness scenarios.",
    notif_bw_error = "Simulation error: %s",
    notif_bw_no_base = "No baseline betweenness analysis available.",
    notif_bw_sim_before_dl = "Please simulate an intervention before downloading betweenness results.",
    notif_bw_net_before_dl = "Please simulate an intervention before downloading the resulting network.",
    notif_code_copied = "R code copied to clipboard successfully!"
  )
)

.app_i18n <- function(key, lang = "es") {
  if (is.null(lang) || !lang %in% c("es", "en")) lang <- "es"
  val <- .app_translations[[lang]][[key]]
  if (is.null(val)) {
    val <- .app_translations[["es"]][[key]]
  }
  if (is.null(val)) key else val
}

# ------------------------------------------------------------------------------
# Internal UI Definition (Bilingual support with real-time reactive DOM updating)
# ------------------------------------------------------------------------------
.create_walk_app_ui <- function(has_initial_net = FALSE, initial_lang = "es") {
  if (is.null(initial_lang) || !initial_lang %in% c("es", "en")) initial_lang <- "es"

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
      shiny::tags$span(id = "i18n_nav_subtitle", style = "font-size: 0.85rem; color: #0A9396; margin-left: 6px; font-weight: 500;", .app_i18n("nav_subtitle", initial_lang))
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
                  {left: '\\[', right: '\\]', display: true},
                  {left: '$', right: '$', display: false},
                  {left: '\\(', right: '\\)', display: false}
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

          // Bilingual Live DOM updater handler
          if (window.Shiny) {
            Shiny.addCustomMessageHandler('update-walkability-i18n', function(message) {
              if (!message || !message.elements) return;
              for (var id in message.elements) {
                var el = document.getElementById(id);
                if (el) {
                  el.innerHTML = message.elements[id];
                }
              }
              if (typeof typesetWalkabilityMath === 'function') {
                typesetWalkabilityMath();
              }
            });
          }

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
          .navbar .shiny-input-container {
            margin-bottom: 0 !important;
          }
          .navbar .selectize-control {
            margin-bottom: 0 !important;
          }
          .navbar .selectize-input {
            padding: 4px 10px !important;
            font-size: 0.85rem !important;
            min-height: 32px !important;
            line-height: 1.3 !important;
          }
        "))
      ),
      shiny::withMathJax()
    ),
    theme = theme,
    fillable = TRUE,
    navbar_options = bslib::navbar_options(collapsible = TRUE),

    # Sidebar global para seleccion de red
    sidebar = bslib::sidebar(
      title = shiny::span(id = "i18n_sidebar_net_title", .app_i18n("sidebar_net_title", initial_lang)),
      width = 300,
      shiny::selectInput(
        inputId = "city_choice",
        label = .app_i18n("city_choice_label", initial_lang),
        choices = stats::setNames(
          c("cusco", "lima", "arequipa", "custom"),
          c(
            .app_i18n("city_cusco", initial_lang),
            .app_i18n("city_lima", initial_lang),
            .app_i18n("city_arequipa", initial_lang),
            .app_i18n("city_custom", initial_lang)
          )
        ),
        selected = "cusco"
      ),
      shiny::conditionalPanel(
        condition = "input.city_choice == 'custom'",
        shiny::fileInput(
          inputId = "user_file",
          label = shiny::span(id = "i18n_user_file_label", .app_i18n("user_file_label", initial_lang)),
          multiple = TRUE,
          accept = c(".gpkg", ".geojson", ".json", ".zip", ".shp", ".dbf", ".shx", ".prj")
        ),
        shiny::textInput(
          inputId = "custom_crs",
          label = .app_i18n("custom_crs_label", initial_lang),
          value = "auto",
          placeholder = .app_i18n("custom_crs_placeholder", initial_lang)
        ),
        shiny::tags$small(
          id = "i18n_custom_crs_help",
          style = "font-size: 0.76rem; color: #6c757d; display: block; margin-top: -6px; margin-bottom: 8px;",
          .app_i18n("custom_crs_help", initial_lang)
        )
      ),
      shiny::hr(),
      shiny::numericInput(
        inputId = "param_speed",
        label = .app_i18n("param_speed_label", initial_lang),
        value = 4.5,
        min = 2.0,
        max = 8.0,
        step = 0.5
      ),
      shiny::checkboxInput(
        inputId = "param_repair",
        label = .app_i18n("param_repair_label", initial_lang),
        value = TRUE
      ),
      shiny::conditionalPanel(
        condition = "input.param_repair == true",
        shiny::tags$div(
          style = "padding: 8px 12px; margin-top: -6px; margin-bottom: 12px; background-color: rgba(0, 95, 115, 0.05); border-left: 3px solid #005F73; border-radius: 4px;",
          shiny::checkboxInput(
            inputId = "param_planarize",
            label = .app_i18n("param_planarize_label", initial_lang),
            value = TRUE
          ),
          shiny::numericInput(
            inputId = "param_snap_tol",
            label = .app_i18n("param_snap_tol_label", initial_lang),
            value = 2.0,
            min = 0.0,
            max = 50.0,
            step = 0.5
          ),
          shiny::tags$small(
            id = "i18n_param_snap_tol_help",
            style = "font-size: 0.75rem; color: #555; display: block; margin-top: -4px;",
            .app_i18n("param_snap_tol_help", initial_lang)
          )
        )
      ),
      shiny::selectInput(
        inputId = "param_components",
        label = .app_i18n("param_components_label", initial_lang),
        choices = stats::setNames(
          c("all", "largest"),
          c(
            .app_i18n("comp_all", initial_lang),
            .app_i18n("comp_largest", initial_lang)
          )
        ),
        selected = "all"
      ),
      shiny::uiOutput("network_status_badge"),
      shiny::downloadButton(
        outputId = "dl_net_edges",
        label = shiny::span(id = "i18n_dl_net_edges", .app_i18n("dl_net_edges_label", initial_lang)),
        class = "btn-sm btn-outline-secondary w-100 mt-2",
        icon = shiny::icon("download")
      ),
      shiny::hr(),
      shiny::tags$div(
        style = "font-size: 0.8rem; color: #6c757d;",
        shiny::tags$p(id = "i18n_sidebar_footer_rust", .app_i18n("sidebar_footer_rust", initial_lang)),
        shiny::tags$p(id = "i18n_sidebar_footer_mapgl", .app_i18n("sidebar_footer_mapgl", initial_lang))
      )
    ),

    # 1. PESTANA: ALCANCE PEATONAL
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_reach", .app_i18n("tab_reach", initial_lang)),
      value = "tab_reach",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = shiny::span(id = "i18n_sidebar_reach_title", .app_i18n("sidebar_reach_title", initial_lang)),
          width = 280,
          shiny::sliderInput(
            inputId = "reach_time_min",
            label = .app_i18n("reach_time_label", initial_lang),
            min = 2,
            max = 20,
            value = 10,
            step = 1
          ),
          shiny::actionButton(
            inputId = "btn_calc_reach",
            label = shiny::span(id = "i18n_btn_calc_reach", .app_i18n("btn_calc_reach", initial_lang)),
            class = "btn-primary w-100",
            icon = shiny::icon("play")
          ),
          shiny::downloadButton(
            outputId = "dl_reach_sf",
            label = shiny::span(id = "i18n_dl_reach_sf", .app_i18n("dl_reach_sf", initial_lang)),
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
          ),
          shiny::hr(),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_reach_mean", .app_i18n("box_reach_mean", initial_lang)),
            value = shiny::textOutput("reach_stat_mean"),
            showcase = shiny::icon("person-walking"),
            theme = "primary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_reach_max", .app_i18n("box_reach_max", initial_lang)),
            value = shiny::textOutput("reach_stat_max"),
            showcase = shiny::icon("award"),
            theme = "secondary"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(shiny::span(id = "i18n_card_reach_header", .app_i18n("card_reach_header", initial_lang))),
          mapgl::maplibreOutput("map_reach", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_reach_doc_title", .app_i18n("reach_doc_title", initial_lang)),
            value = "panel_reach_doc",
            icon = shiny::icon("circle-info"),
            shiny::div(id = "i18n_reach_doc_content", shiny::HTML(.app_i18n("reach_doc_html", initial_lang)))
          )
        )
      )
    ),

    # 2. PESTANA: ISOCRONAS MULTITEMPORALES
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_iso", .app_i18n("tab_iso", initial_lang)),
      value = "tab_iso",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = shiny::span(id = "i18n_sidebar_iso_title", .app_i18n("sidebar_iso_title", initial_lang)),
          width = 300,
          shiny::tags$p(
            id = "i18n_iso_help_click",
            style = "font-size: 0.85rem; color: #495057;",
            .app_i18n("iso_help_click", initial_lang)
          ),
          shiny::textOutput("iso_origin_label"),
          shiny::hr(),
          shiny::selectizeInput(
            inputId = "iso_cutoffs",
            label = .app_i18n("iso_cutoffs_label", initial_lang),
            choices = c("3 min" = 3, "5 min" = 5, "10 min" = 10, "15 min" = 15, "20 min" = 20),
            selected = c(5, 10, 15),
            multiple = TRUE,
            options = list(
              create = TRUE,
              placeholder = "3, 5, 10...",
              plugins = list("remove_button")
            )
          ),
          shiny::textInput(
            inputId = "iso_custom_times_text",
            label = .app_i18n("iso_custom_times_label", initial_lang),
            value = "",
            placeholder = .app_i18n("iso_custom_times_placeholder", initial_lang)
          ),
          shiny::uiOutput("iso_times_preview"),
          shiny::checkboxInput(
            inputId = "iso_rings",
            label = .app_i18n("iso_rings_label", initial_lang),
            value = TRUE
          ),
          shiny::selectInput(
            inputId = "iso_method",
            label = .app_i18n("iso_method_label", initial_lang),
            choices = stats::setNames(
              c("concave", "buffer"),
              c(.app_i18n("iso_method_concave", initial_lang), .app_i18n("iso_method_buffer", initial_lang))
            ),
            selected = "concave"
          ),
          shiny::actionButton(
            inputId = "btn_calc_iso",
            label = shiny::span(id = "i18n_btn_calc_iso", .app_i18n("btn_calc_iso", initial_lang)),
            class = "btn-success w-100",
            icon = shiny::icon("bullseye")
          ),
          shiny::downloadButton(
            outputId = "dl_iso_sf",
            label = shiny::span(id = "i18n_dl_iso_sf", .app_i18n("dl_iso_sf", initial_lang)),
            class = "btn-sm btn-outline-success w-100 mt-2",
            icon = shiny::icon("download")
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(shiny::span(id = "i18n_card_iso_header", .app_i18n("card_iso_header", initial_lang))),
          mapgl::maplibreOutput("map_iso", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_iso_table_title", .app_i18n("table_iso_bands_title", initial_lang)),
            value = "panel_iso_table",
            icon = shiny::icon("table"),
            shiny::tableOutput("table_iso_bands")
          ),
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_iso_doc_title", .app_i18n("iso_doc_title", initial_lang)),
            value = "panel_iso_doc",
            icon = shiny::icon("circle-info"),
            shiny::div(id = "i18n_accord_iso_doc_content", shiny::HTML(.app_i18n("iso_doc_html", initial_lang)))
          )
        )
      )
    ),

    # 3. PESTANA: RUTEO Y CIRCUIDAD
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_route", .app_i18n("tab_route", initial_lang)),
      value = "tab_route",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = shiny::span(id = "i18n_sidebar_route_title", .app_i18n("sidebar_route_title", initial_lang)),
          width = 300,
          shiny::radioButtons(
            inputId = "route_mode",
            label = .app_i18n("route_mode_label", initial_lang),
            choices = stats::setNames(
              c("origin", "dest"),
              c(.app_i18n("route_mode_origin", initial_lang), .app_i18n("route_mode_dest", initial_lang))
            ),
            selected = "origin"
          ),
          shiny::actionButton(
            inputId = "btn_random_route",
            label = shiny::span(id = "i18n_btn_random_route", .app_i18n("btn_random_route", initial_lang)),
            class = "btn-secondary w-100 mb-2",
            icon = shiny::icon("shuffle")
          ),
          shiny::actionButton(
            inputId = "btn_calc_route",
            label = shiny::span(id = "i18n_btn_calc_route", .app_i18n("btn_calc_route", initial_lang)),
            class = "btn-primary w-100",
            icon = shiny::icon("route")
          ),
          shiny::downloadButton(
            outputId = "dl_route_sf",
            label = shiny::span(id = "i18n_dl_route_sf", .app_i18n("dl_route_sf", initial_lang)),
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
          ),
          shiny::hr(),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_route_dist", .app_i18n("box_route_dist", initial_lang)),
            value = shiny::textOutput("route_dist"),
            showcase = shiny::icon("road"),
            theme = "primary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_route_time", .app_i18n("box_route_time", initial_lang)),
            value = shiny::textOutput("route_time"),
            showcase = shiny::icon("stopwatch"),
            theme = "secondary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_route_circuity", .app_i18n("box_route_circuity", initial_lang)),
            value = shiny::textOutput("route_circuity"),
            showcase = shiny::icon("arrows-split-up-and-left"),
            theme = "warning"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(shiny::span(id = "i18n_card_route_header", .app_i18n("card_route_header", initial_lang))),
          mapgl::maplibreOutput("map_route", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_route_doc_title", .app_i18n("route_doc_title", initial_lang)),
            value = "panel_route_doc",
            icon = shiny::icon("circle-info"),
            shiny::div(id = "i18n_accord_route_doc_content", shiny::HTML(.app_i18n("route_doc_html", initial_lang)))
          )
        )
      )
    ),

    # 4. PESTANA: MORFOLOGIA Y CRUCES
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_morph", .app_i18n("tab_morph", initial_lang)),
      value = "tab_morph",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = shiny::span(id = "i18n_sidebar_morph_title", .app_i18n("sidebar_morph_title", initial_lang)),
          width = 320,
          shiny::checkboxGroupInput(
            inputId = "morph_classes",
            label = .app_i18n("morph_classes_label", initial_lang),
            choices = stats::setNames(
              c(1, 3, 4),
              c(
                .app_i18n("morph_class_1", initial_lang),
                .app_i18n("morph_class_3", initial_lang),
                .app_i18n("morph_class_4", initial_lang)
              )
            ),
            selected = c(1, 3, 4)
          ),
          # Leyenda interactiva de morfologia
          shiny::div(
            id = "i18n_morph_legend_box",
            class = "morph-legend-box my-2",
            shiny::HTML(.app_i18n("morph_legend_html", initial_lang))
          ),
          shiny::downloadButton(
            outputId = "dl_morph_sf",
            label = shiny::span(id = "i18n_dl_morph_sf", .app_i18n("dl_morph_sf", initial_lang)),
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
          ),
          shiny::hr(),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_morph_density", .app_i18n("box_morph_density", initial_lang)),
            value = shiny::textOutput("morph_density"),
            showcase = shiny::icon("map-location-dot"),
            theme = "primary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_morph_culdesac", .app_i18n("box_morph_culdesac", initial_lang)),
            value = shiny::textOutput("morph_culdesac"),
            showcase = shiny::icon("ban"),
            theme = "danger"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_morph_ortho", .app_i18n("box_morph_ortho", initial_lang)),
            value = shiny::textOutput("morph_ortho"),
            showcase = shiny::icon("draw-polygon"),
            theme = "success"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(shiny::span(id = "i18n_card_morph_header", .app_i18n("card_morph_header", initial_lang))),
          mapgl::maplibreOutput("map_morph", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_morph_doc_title", .app_i18n("morph_doc_title", initial_lang)),
            value = "panel_morph_doc",
            icon = shiny::icon("circle-info"),
            shiny::div(id = "i18n_accord_morph_doc_content", shiny::HTML(.app_i18n("morph_doc_html", initial_lang)))
          )
        )
      )
    ),

    # 5. PESTANA: SIMULACION DE ESCENARIOS E INTERMEDIACION
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_scen", .app_i18n("tab_scen", initial_lang)),
      value = "tab_scen",
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(
          title = shiny::span(id = "i18n_sidebar_scen_title", .app_i18n("sidebar_scen_title", initial_lang)),
          width = 330,
          shiny::radioButtons(
            inputId = "scen_view_mode",
            label = .app_i18n("scen_view_label", initial_lang),
            choices = stats::setNames(
              c("base_bw", "sim_bw", "delta_bw"),
              c(
                .app_i18n("scen_view_base", initial_lang),
                .app_i18n("scen_view_sim", initial_lang),
                .app_i18n("scen_view_delta", initial_lang)
              )
            ),
            selected = "base_bw"
          ),
          shiny::hr(),
          shiny::sliderInput(
            inputId = "scen_snap_radius",
            label = .app_i18n("scen_snap_label", initial_lang),
            min = 0,
            max = 25,
            value = 0,
            step = 1
          ),
          shiny::tags$p(
            id = "i18n_scen_snap_help",
            class = "text-muted",
            style = "font-size: 0.8rem; margin-top: -6px; margin-bottom: 8px;",
            .app_i18n("scen_snap_help", initial_lang)
          ),
          shiny::selectInput(
            inputId = "scen_analysis_radius",
            label = .app_i18n("scen_radius_label", initial_lang),
            choices = stats::setNames(
              c("0", "400", "800", "1200"),
              c(
                .app_i18n("scen_rad_global", initial_lang),
                .app_i18n("scen_rad_400", initial_lang),
                .app_i18n("scen_rad_800", initial_lang),
                .app_i18n("scen_rad_1200", initial_lang)
              )
            ),
            selected = "0"
          ),
          shiny::actionButton(
            inputId = "btn_recalc_bw_base",
            label = shiny::span(id = "i18n_btn_recalc_bw_base", .app_i18n("btn_recalc_bw_base", initial_lang)),
            class = "btn-sm btn-outline-primary w-100 mb-2",
            icon = shiny::icon("rotate")
          ),
          shiny::hr(),
          shiny::tags$p(
            id = "i18n_scen_edge_instruction",
            style = "font-size: 0.85rem; color: #495057; margin-bottom: 6px; font-weight: 600;",
            .app_i18n("scen_edge_instruction", initial_lang)
          ),
          shiny::selectizeInput(
            inputId = "scen_edge_select",
            label = NULL,
            choices = NULL,
            multiple = TRUE,
            options = list(
              placeholder = .app_i18n("scen_edge_placeholder", initial_lang),
              maxOptions = 100,
              plugins = list("remove_button")
            )
          ),
          shiny::uiOutput("scen_selected_info"),
          shiny::div(
            class = "d-flex gap-2 mb-2",
            shiny::actionButton(
              inputId = "btn_clear_scen",
              label = shiny::span(id = "i18n_btn_clear_scen", .app_i18n("btn_clear_scen", initial_lang)),
              class = "btn-sm btn-outline-danger w-50",
              icon = shiny::icon("trash")
            ),
            shiny::actionButton(
              inputId = "btn_sample_random",
              label = shiny::span(id = "i18n_btn_sample_random", .app_i18n("btn_sample_random", initial_lang)),
              class = "btn-sm btn-outline-secondary w-50",
              icon = shiny::icon("shuffle")
            )
          ),
          shiny::actionButton(
            inputId = "btn_pick_top_bottleneck",
            label = shiny::span(id = "i18n_btn_pick_top_bottleneck", .app_i18n("btn_pick_top_bottleneck", initial_lang)),
            class = "btn-sm btn-outline-danger w-100 mb-2",
            icon = shiny::icon("fire")
          ),
          shiny::sliderInput(
            inputId = "scen_random_n",
            label = .app_i18n("scen_random_n_label", initial_lang),
            min = 1,
            max = 15,
            value = 3,
            step = 1
          ),
          shiny::actionButton(
            inputId = "btn_sim_scenario",
            label = shiny::span(id = "i18n_btn_sim_scenario", .app_i18n("btn_sim_scenario", initial_lang)),
            class = "btn-warning w-100 fw-bold",
            icon = shiny::icon("traffic-light")
          ),
          shiny::downloadButton(
            outputId = "dl_betweenness_base_sf",
            label = shiny::span(id = "i18n_dl_bw_base_sf", .app_i18n("dl_bw_base_sf", initial_lang)),
            class = "btn-sm btn-outline-primary w-100 mt-2",
            icon = shiny::icon("download")
          ),
          shiny::downloadButton(
            outputId = "dl_betweenness_sim_sf",
            label = shiny::span(id = "i18n_dl_bw_sim_sf", .app_i18n("dl_bw_sim_sf", initial_lang)),
            class = "btn-sm btn-outline-success w-100 mt-1",
            icon = shiny::icon("download")
          ),
          shiny::downloadButton(
            outputId = "dl_scen_sf",
            label = shiny::span(id = "i18n_dl_scen_sf", .app_i18n("dl_scen_sf", initial_lang)),
            class = "btn-sm btn-outline-secondary w-100 mt-1",
            icon = shiny::icon("download")
          ),
          shiny::hr(),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_scen_bottleneck", .app_i18n("box_scen_bottleneck", initial_lang)),
            value = shiny::textOutput("scen_top_base_stat"),
            showcase = shiny::icon("bridge"),
            theme = "primary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_scen_diverted", .app_i18n("box_scen_diverted", initial_lang)),
            value = shiny::textOutput("scen_top_sim_stat"),
            showcase = shiny::icon("arrows-split-up-and-left"),
            theme = "danger"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_scen_closed_len", .app_i18n("box_scen_closed_len", initial_lang)),
            value = shiny::textOutput("scen_closed_len"),
            showcase = shiny::icon("scissors"),
            theme = "secondary"
          ),
          bslib::value_box(
            title = shiny::span(id = "i18n_box_scen_mean_bw", .app_i18n("box_scen_mean_bw", initial_lang)),
            value = shiny::textOutput("scen_delta_bw_stat"),
            showcase = shiny::icon("chart-line"),
            theme = "warning"
          )
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header(shiny::span(id = "i18n_card_scen_header", .app_i18n("card_scen_header", initial_lang))),
          mapgl::maplibreOutput("map_scenarios", height = "640px")
        ),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_scen_table_top_title", .app_i18n("table_diverted_title", initial_lang)),
            value = "panel_scen_table_top",
            icon = shiny::icon("arrow-trend-up"),
            shiny::tableOutput("table_top_diverted")
          ),
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_scen_table_closed_title", .app_i18n("table_closed_title", initial_lang)),
            value = "panel_scen_table_closed",
            icon = shiny::icon("table-list"),
            shiny::tableOutput("table_closed_edges")
          ),
          bslib::accordion_panel(
            title = shiny::span(id = "i18n_accord_scen_doc_title", .app_i18n("scen_doc_title", initial_lang)),
            value = "panel_scen_doc",
            icon = shiny::icon("circle-info"),
            shiny::div(id = "i18n_accord_scen_doc_content", shiny::HTML(.app_i18n("scen_doc_html", initial_lang)))
          )
        )
      )
    ),

    # 6. PESTANA: GUIA Y GENERADOR DE CODIGO R
    bslib::nav_panel(
      title = shiny::span(id = "i18n_tab_code", .app_i18n("tab_code", initial_lang)),
      value = "tab_code",
      bslib::card(
        bslib::card_header(
          shiny::div(
            class = "d-flex justify-content-between align-items-center w-100",
            shiny::div(
              shiny::span(id = "i18n_tab_code_title", shiny::tags$strong(.app_i18n("tab_code_header", initial_lang))),
              shiny::span(id = "i18n_tab_code_sync", paste0(" ", .app_i18n("tab_code_sync", initial_lang)))
            ),
            shiny::div(
              class = "d-flex gap-2",
              shiny::actionButton(
                inputId = "btn_copy_code",
                label = shiny::span(id = "i18n_btn_copy_code", .app_i18n("btn_copy_code", initial_lang)),
                icon = shiny::icon("copy"),
                class = "btn-sm btn-outline-primary",
                onclick = "copyCodeToClipboard()"
              ),
              shiny::downloadButton(
                outputId = "dl_code_script",
                label = shiny::span(id = "i18n_dl_code_script", .app_i18n("dl_code_script", initial_lang)),
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
              label = .app_i18n("code_filter_label", initial_lang),
              choices = stats::setNames(
                c("all", "network", "reach", "iso", "route", "morph", "scen"),
                c(
                  .app_i18n("code_filt_all", initial_lang),
                  .app_i18n("code_filt_net", initial_lang),
                  .app_i18n("code_filt_reach", initial_lang),
                  .app_i18n("code_filt_iso", initial_lang),
                  .app_i18n("code_filt_route", initial_lang),
                  .app_i18n("code_filt_morph", initial_lang),
                  .app_i18n("code_filt_scen", initial_lang)
                )
              ),
              selected = "all"
            )
          ),
          shiny::div(
            class = "col-md-7 d-flex align-items-center",
            shiny::tags$p(
              id = "i18n_code_info_text",
              class = "text-muted mb-0",
              style = "font-size: 0.85rem;",
              .app_i18n("code_info_text", initial_lang)
            )
          )
        ),
        shiny::div(
          class = "tex2jax_ignore no-math",
          shiny::verbatimTextOutput("code_text_display")
        )
      )
    ),

    # Nav Spacer & Selector de Idioma
    bslib::nav_spacer(),
    bslib::nav_item(
      shiny::div(
        style = "display: flex; align-items: center; gap: 6px; padding: 0 4px;",
        shiny::tags$span(style = "font-size: 1.15rem; line-height: 1;", "\U0001f310"),
        shiny::tags$div(
          style = "min-width: 110px;",
          shiny::selectInput(
            inputId = "app_lang",
            label = NULL,
            choices = c("Espa\u00f1ol" = "es", "English" = "en"),
            selected = initial_lang,
            width = "110px"
          )
        )
      )
    )
  )
}

# Spatial Loader for Custom Uploads (GeoPackage, Zipped Shapefile, GeoJSON, Multi-file Shapefile)
.load_spatial_network_from_upload <- function(user_file_df, crs_param = "auto", walk_speed_kmh = 4.5, repair = TRUE, planarize = FALSE, snap_tolerance_m = 0.0, keep_components = "all") {
  if (is.null(user_file_df) || nrow(user_file_df) == 0) return(NULL)

  work_dir <- tempfile(pattern = "walk_spatial_")
  dir.create(work_dir, recursive = TRUE)
  on.exit(unlink(work_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Copy uploaded files preserving original names
  for (i in seq_len(nrow(user_file_df))) {
    dest <- file.path(work_dir, user_file_df$name[i])
    file.copy(user_file_df$datapath[i], dest, overwrite = TRUE)
  }

  # Unzip any zip archives
  zip_files <- list.files(work_dir, pattern = "\\.zip$", ignore.case = TRUE, full.names = TRUE)
  if (length(zip_files) > 0) {
    for (zf in zip_files) {
      unzip_dir <- file.path(work_dir, "unzipped")
      dir.create(unzip_dir, recursive = TRUE, showWarnings = FALSE)
      utils::unzip(zf, exdir = unzip_dir, unzip = "internal")
    }
  }

  all_files <- list.files(work_dir, recursive = TRUE, full.names = TRUE)
  # Exclude macOS metadata files
  all_files <- all_files[!grepl("__MACOSX|/\\._|\\\\\\._", all_files)]

  shp_f <- all_files[grepl("\\.shp$", all_files, ignore.case = TRUE)]
  gpkg_f <- all_files[grepl("\\.gpkg$", all_files, ignore.case = TRUE)]
  geojson_f <- all_files[grepl("\\.(geojson|json)$", all_files, ignore.case = TRUE)]

  target_file <- NULL
  file_format <- NULL

  if (length(shp_f) > 0) {
    target_file <- shp_f[1]
    file_format <- "Shapefile (.shp)"
    raw_sf <- sf::st_read(target_file, quiet = TRUE)
  } else if (length(gpkg_f) > 0) {
    target_file <- gpkg_f[1]
    file_format <- "GeoPackage (.gpkg)"
    layers_info <- sf::st_layers(target_file)
    chosen_layer <- layers_info$name[1]
    if (length(layers_info$name) > 1) {
      line_idx <- which(grepl("line|street|road|edge|tramo|vial|calle|red", layers_info$name, ignore.case = TRUE))
      if (length(line_idx) > 0) {
        chosen_layer <- layers_info$name[line_idx[1]]
      } else {
        gtype_idx <- which(grepl("line", tolower(as.character(layers_info$geomtype %||% ""))))
        if (length(gtype_idx) > 0) chosen_layer <- layers_info$name[gtype_idx[1]]
      }
    }
    raw_sf <- sf::st_read(target_file, layer = chosen_layer, quiet = TRUE)
  } else if (length(geojson_f) > 0) {
    target_file <- geojson_f[1]
    file_format <- "GeoJSON (.geojson)"
    raw_sf <- sf::st_read(target_file, quiet = TRUE)
  } else {
    stop("No se detect\u00f3 ning\u00fan archivo espacial compatible (.shp, .gpkg, .geojson, .zip).")
  }

  # Ensure 2D (drop Z and M coordinates if present)
  raw_sf <- sf::st_zm(raw_sf, drop = TRUE, what = "ZM")

  # Filter linear geometries (LINESTRING, MULTILINESTRING)
  gtypes <- as.character(sf::st_geometry_type(raw_sf, by_geometry = TRUE))
  line_idx <- which(gtypes %in% c("LINESTRING", "MULTILINESTRING"))
  if (length(line_idx) > 0) {
    raw_sf <- raw_sf[line_idx, ]
  } else {
    raw_sf <- tryCatch(sf::st_collection_extract(raw_sf, "LINESTRING"), error = function(e) raw_sf[0, ])
  }

  if (nrow(raw_sf) == 0) {
    stop("El archivo no contiene geometr\u00edas lineales (calles o tramos) utilizables para la red.")
  }

  # CRS Handling & Metric Projection
  current_crs <- sf::st_crs(raw_sf)
  is_missing_crs <- is.na(current_crs) || is.null(current_crs$input)
  target_crs_code <- NULL

  crs_input_clean <- trimws(tolower(as.character(crs_param %||% "auto")))
  if (nzchar(crs_input_clean) && crs_input_clean != "auto") {
    num_code <- as.integer(gsub("[^0-9]", "", crs_input_clean))
    if (!is.na(num_code) && num_code > 0) {
      target_crs_code <- num_code
    }
  }

  crs_note <- ""
  if (is_missing_crs) {
    bb <- sf::st_bbox(raw_sf)
    if (bb["xmin"] >= -180 && bb["xmax"] <= 180 && bb["ymin"] >= -90 && bb["ymax"] <= 90) {
      sf::st_crs(raw_sf) <- 4326
      current_crs <- sf::st_crs(raw_sf)
      crs_note <- "CRS asumido WGS84"
    } else {
      if (is.null(target_crs_code)) target_crs_code <- 3857
      sf::st_crs(raw_sf) <- target_crs_code
      current_crs <- sf::st_crs(raw_sf)
      crs_note <- paste0("CRS asumido EPSG:", target_crs_code)
    }
  }

  if (sf::st_is_longlat(raw_sf)) {
    if (is.null(target_crs_code)) {
      wgs84_sf <- sf::st_transform(raw_sf, 4326)
      bb <- sf::st_bbox(wgs84_sf)
      lon_c <- (bb["xmin"] + bb["xmax"]) / 2
      lat_c <- (bb["ymin"] + bb["ymax"]) / 2
      utm_z <- floor((lon_c + 180) / 6) + 1
      target_crs_code <- if (lat_c >= 0) 32600 + utm_z else 32700 + utm_z
      crs_note <- sprintf("WGS84 proyectado autom\u00e1ticamente a UTM Zona %d%s (EPSG:%d)",
                          utm_z, if (lat_c >= 0) "N" else "S", target_crs_code)
    } else {
      crs_note <- sprintf("WGS84 proyectado a EPSG:%d", target_crs_code)
    }
    raw_sf <- sf::st_transform(raw_sf, as.integer(target_crs_code))
  } else if (!is.null(target_crs_code)) {
    raw_sf <- sf::st_transform(raw_sf, as.integer(target_crs_code))
    crs_note <- sprintf("Proyectado a EPSG:%d", target_crs_code)
  } else {
    crs_epsg <- sf::st_crs(raw_sf)$epsg
    crs_note <- if (!is.null(crs_epsg) && !is.na(crs_epsg)) sprintf("M\u00e9trico nativo (EPSG:%s)", crs_epsg) else "M\u00e9trico nativo"
  }

  net <- walk_build_network(
    data = raw_sf,
    walk_speed_kmh = walk_speed_kmh,
    repair = repair,
    planarize = planarize,
    snap_tolerance_m = snap_tolerance_m,
    keep_components = keep_components,
    drop_classes = character(0),
    verbose = FALSE
  )

  list(
    network = net,
    format = file_format,
    target_file = basename(target_file),
    raw_features = nrow(raw_sf),
    crs_note = crs_note,
    epsg = sf::st_crs(raw_sf)$epsg,
    planarize = planarize,
    snap_tolerance_m = snap_tolerance_m
  )
}

# ------------------------------------------------------------------------------
# Internal Server Definition (Bilingual support with real-time reactive updates)
# ------------------------------------------------------------------------------
.create_walk_app_server <- function(initial_network = NULL, initial_lang = "es") {
  if (is.null(initial_lang) || !initial_lang %in% c("es", "en")) initial_lang <- "es"

  function(input, output, session) {
    # Active language state holder
    current_lang <- shiny::reactiveVal(initial_lang)

    # 1. Reactive Network Management
    current_net <- shiny::reactiveVal(initial_network)
    network_meta <- shiny::reactiveVal(if (!is.null(initial_network)) list(
      format = "Red predefinida",
      target_file = "initial_network",
      crs_note = "M\u00e9trico proyectado",
      epsg = sf::st_crs(initial_network$nodes)$epsg
    ) else NULL)
    network_error <- shiny::reactiveVal(NULL)

    # Core reactive state holders across tabs
    reach_res <- shiny::reactiveVal(NULL)
    iso_origin_coords <- shiny::reactiveVal(NULL)
    iso_res <- shiny::reactiveVal(NULL)
    route_pt_a <- shiny::reactiveVal(NULL)
    route_pt_b <- shiny::reactiveVal(NULL)
    route_res <- shiny::reactiveVal(NULL)
    bw_base_res <- shiny::reactiveVal(NULL)
    bw_sim_res <- shiny::reactiveVal(NULL)
    scen_res <- shiny::reactiveVal(NULL)

    # Language Switch Observer: updates inputs and dispatches custom DOM message
    shiny::observeEvent(input$app_lang, {
      new_lang <- input$app_lang
      if (is.null(new_lang) || !new_lang %in% c("es", "en")) return()
      if (identical(new_lang, shiny::isolate(current_lang()))) return()
      current_lang(new_lang)

      # 1. Update Inputs
      shiny::updateSelectInput(
        session,
        "city_choice",
        label = .app_i18n("city_choice_label", new_lang),
        choices = stats::setNames(
          c("cusco", "lima", "arequipa", "custom"),
          c(
            .app_i18n("city_cusco", new_lang),
            .app_i18n("city_lima", new_lang),
            .app_i18n("city_arequipa", new_lang),
            .app_i18n("city_custom", new_lang)
          )
        ),
        selected = input$city_choice
      )

      shiny::updateTextInput(
        session,
        "custom_crs",
        label = .app_i18n("custom_crs_label", new_lang),
        placeholder = .app_i18n("custom_crs_placeholder", new_lang)
      )

      shiny::updateNumericInput(
        session,
        "param_speed",
        label = .app_i18n("param_speed_label", new_lang)
      )

      shiny::updateCheckboxInput(
        session,
        "param_repair",
        label = .app_i18n("param_repair_label", new_lang)
      )

      shiny::updateCheckboxInput(
        session,
        "param_planarize",
        label = .app_i18n("param_planarize_label", new_lang)
      )

      shiny::updateNumericInput(
        session,
        "param_snap_tol",
        label = .app_i18n("param_snap_tol_label", new_lang)
      )

      shiny::updateSelectInput(
        session,
        "param_components",
        label = .app_i18n("param_components_label", new_lang),
        choices = stats::setNames(
          c("all", "largest"),
          c(.app_i18n("comp_all", new_lang), .app_i18n("comp_largest", new_lang))
        ),
        selected = input$param_components
      )

      shiny::updateSliderInput(
        session,
        "reach_time_min",
        label = .app_i18n("reach_time_label", new_lang)
      )

      shiny::updateSelectInput(
        session,
        "iso_method",
        label = .app_i18n("iso_method_label", new_lang),
        choices = stats::setNames(
          c("concave", "buffer"),
          c(.app_i18n("iso_method_concave", new_lang), .app_i18n("iso_method_buffer", new_lang))
        ),
        selected = input$iso_method
      )

      shiny::updateCheckboxInput(
        session,
        "iso_rings",
        label = .app_i18n("iso_rings_label", new_lang)
      )

      shiny::updateRadioButtons(
        session,
        "route_mode",
        label = .app_i18n("route_mode_label", new_lang),
        choices = stats::setNames(
          c("origin", "dest"),
          c(.app_i18n("route_mode_origin", new_lang), .app_i18n("route_mode_dest", new_lang))
        ),
        selected = input$route_mode
      )

      shiny::updateCheckboxGroupInput(
        session,
        "morph_classes",
        label = .app_i18n("morph_classes_label", new_lang),
        choices = stats::setNames(
          c(1, 3, 4),
          c(
            .app_i18n("morph_class_1", new_lang),
            .app_i18n("morph_class_3", new_lang),
            .app_i18n("morph_class_4", new_lang)
          )
        ),
        selected = input$morph_classes
      )

      shiny::updateRadioButtons(
        session,
        "scen_view_mode",
        label = .app_i18n("scen_view_label", new_lang),
        choices = stats::setNames(
          c("base_bw", "sim_bw", "delta_bw"),
          c(
            .app_i18n("scen_view_base", new_lang),
            .app_i18n("scen_view_sim", new_lang),
            .app_i18n("scen_view_delta", new_lang)
          )
        ),
        selected = input$scen_view_mode
      )

      shiny::updateSliderInput(
        session,
        "scen_snap_radius",
        label = .app_i18n("scen_snap_label", new_lang)
      )

      shiny::updateSelectInput(
        session,
        "scen_analysis_radius",
        label = .app_i18n("scen_radius_label", new_lang),
        choices = stats::setNames(
          c("0", "400", "800", "1200"),
          c(
            .app_i18n("scen_rad_global", new_lang),
            .app_i18n("scen_rad_400", new_lang),
            .app_i18n("scen_rad_800", new_lang),
            .app_i18n("scen_rad_1200", new_lang)
          )
        ),
        selected = input$scen_analysis_radius
      )

      shiny::updateSliderInput(
        session,
        "scen_random_n",
        label = .app_i18n("scen_random_n_label", new_lang)
      )

      shiny::updateSelectInput(
        session,
        "code_module_filter",
        label = .app_i18n("code_filter_label", new_lang),
        choices = stats::setNames(
          c("all", "network", "reach", "iso", "route", "morph", "scen"),
          c(
            .app_i18n("code_filt_all", new_lang),
            .app_i18n("code_filt_net", new_lang),
            .app_i18n("code_filt_reach", new_lang),
            .app_i18n("code_filt_iso", new_lang),
            .app_i18n("code_filt_route", new_lang),
            .app_i18n("code_filt_morph", new_lang),
            .app_i18n("code_filt_scen", new_lang)
          )
        ),
        selected = input$code_module_filter
      )

      # 2. Push static DOM string replacements to custom JS handler
      session$sendCustomMessage("update-walkability-i18n", list(
        lang = new_lang,
        elements = list(
          i18n_nav_subtitle = .app_i18n("nav_subtitle", new_lang),
          i18n_tab_reach = .app_i18n("tab_reach", new_lang),
          i18n_tab_iso = .app_i18n("tab_iso", new_lang),
          i18n_tab_route = .app_i18n("tab_route", new_lang),
          i18n_tab_morph = .app_i18n("tab_morph", new_lang),
          i18n_tab_scen = .app_i18n("tab_scen", new_lang),
          i18n_tab_code = .app_i18n("tab_code", new_lang),

          i18n_sidebar_net_title = .app_i18n("sidebar_net_title", new_lang),
          i18n_user_file_label = .app_i18n("user_file_label", new_lang),
          i18n_custom_crs_help = .app_i18n("custom_crs_help", new_lang),
          i18n_param_snap_tol_help = .app_i18n("param_snap_tol_help", new_lang),
          i18n_dl_net_edges = .app_i18n("dl_net_edges_label", new_lang),
          i18n_sidebar_footer_rust = .app_i18n("sidebar_footer_rust", new_lang),
          i18n_sidebar_footer_mapgl = .app_i18n("sidebar_footer_mapgl", new_lang),

          i18n_sidebar_reach_title = .app_i18n("sidebar_reach_title", new_lang),
          i18n_btn_calc_reach = .app_i18n("btn_calc_reach", new_lang),
          i18n_dl_reach_sf = .app_i18n("dl_reach_sf", new_lang),
          i18n_box_reach_mean = .app_i18n("box_reach_mean", new_lang),
          i18n_box_reach_max = .app_i18n("box_reach_max", new_lang),
          i18n_card_reach_header = .app_i18n("card_reach_header", new_lang),
          i18n_reach_doc_title = .app_i18n("reach_doc_title", new_lang),
          i18n_reach_doc_content = .app_i18n("reach_doc_html", new_lang),

          i18n_sidebar_iso_title = .app_i18n("sidebar_iso_title", new_lang),
          i18n_iso_help_click = .app_i18n("iso_help_click", new_lang),
          i18n_btn_calc_iso = .app_i18n("btn_calc_iso", new_lang),
          i18n_dl_iso_sf = .app_i18n("dl_iso_sf", new_lang),
          i18n_card_iso_header = .app_i18n("card_iso_header", new_lang),
          i18n_accord_iso_table_title = .app_i18n("table_iso_bands_title", new_lang),
          i18n_accord_iso_doc_title = .app_i18n("iso_doc_title", new_lang),
          i18n_accord_iso_doc_content = .app_i18n("iso_doc_html", new_lang),

          i18n_sidebar_route_title = .app_i18n("sidebar_route_title", new_lang),
          i18n_btn_random_route = .app_i18n("btn_random_route", new_lang),
          i18n_btn_calc_route = .app_i18n("btn_calc_route", new_lang),
          i18n_dl_route_sf = .app_i18n("dl_route_sf", new_lang),
          i18n_box_route_dist = .app_i18n("box_route_dist", new_lang),
          i18n_box_route_time = .app_i18n("box_route_time", new_lang),
          i18n_box_route_circuity = .app_i18n("box_route_circuity", new_lang),
          i18n_card_route_header = .app_i18n("card_route_header", new_lang),
          i18n_accord_route_doc_title = .app_i18n("route_doc_title", new_lang),
          i18n_accord_route_doc_content = .app_i18n("route_doc_html", new_lang),

          i18n_sidebar_morph_title = .app_i18n("sidebar_morph_title", new_lang),
          i18n_morph_legend_box = .app_i18n("morph_legend_html", new_lang),
          i18n_dl_morph_sf = .app_i18n("dl_morph_sf", new_lang),
          i18n_box_morph_density = .app_i18n("box_morph_density", new_lang),
          i18n_box_morph_culdesac = .app_i18n("box_morph_culdesac", new_lang),
          i18n_box_morph_ortho = .app_i18n("box_morph_ortho", new_lang),
          i18n_card_morph_header = .app_i18n("card_morph_header", new_lang),
          i18n_accord_morph_doc_title = .app_i18n("morph_doc_title", new_lang),
          i18n_accord_morph_doc_content = .app_i18n("morph_doc_html", new_lang),

          i18n_sidebar_scen_title = .app_i18n("sidebar_scen_title", new_lang),
          i18n_scen_snap_help = .app_i18n("scen_snap_help", new_lang),
          i18n_btn_recalc_bw_base = .app_i18n("btn_recalc_bw_base", new_lang),
          i18n_scen_edge_instruction = .app_i18n("scen_edge_instruction", new_lang),
          i18n_btn_clear_scen = .app_i18n("btn_clear_scen", new_lang),
          i18n_btn_sample_random = .app_i18n("btn_sample_random", new_lang),
          i18n_btn_pick_top_bottleneck = .app_i18n("btn_pick_top_bottleneck", new_lang),
          i18n_btn_sim_scenario = .app_i18n("btn_sim_scenario", new_lang),
          i18n_dl_bw_base_sf = .app_i18n("dl_bw_base_sf", new_lang),
          i18n_dl_bw_sim_sf = .app_i18n("dl_bw_sim_sf", new_lang),
          i18n_dl_scen_sf = .app_i18n("dl_scen_sf", new_lang),
          i18n_box_scen_bottleneck = .app_i18n("box_scen_bottleneck", new_lang),
          i18n_box_scen_diverted = .app_i18n("box_scen_diverted", new_lang),
          i18n_box_scen_closed_len = .app_i18n("box_scen_closed_len", new_lang),
          i18n_box_scen_mean_bw = .app_i18n("box_scen_mean_bw", new_lang),
          i18n_card_scen_header = .app_i18n("card_scen_header", new_lang),
          i18n_accord_scen_table_top_title = .app_i18n("table_diverted_title", new_lang),
          i18n_accord_scen_table_closed_title = .app_i18n("table_closed_title", new_lang),
          i18n_accord_scen_doc_title = .app_i18n("scen_doc_title", new_lang),
          i18n_accord_scen_doc_content = .app_i18n("scen_doc_html", new_lang),

          i18n_tab_code_title = paste0("<strong>", .app_i18n("tab_code_header", new_lang), "</strong>"),
          i18n_tab_code_sync = paste0(" ", .app_i18n("tab_code_sync", new_lang)),
          i18n_btn_copy_code = .app_i18n("btn_copy_code", new_lang),
          i18n_dl_code_script = .app_i18n("dl_code_script", new_lang),
          i18n_code_info_text = .app_i18n("code_info_text", new_lang)
        )
      ))
    }, ignoreInit = TRUE)

    shiny::observe({
      city <- input$city_choice
      if (city == "custom") {
        if (is.null(input$user_file)) {
          network_error(NULL)
          return()
        }

        shiny::withProgress(message = if (current_lang() == "en") "Loading custom spatial dataset..." else "Cargando archivo espacial...", value = 0.2, {
          tryCatch({
            res <- .load_spatial_network_from_upload(
              user_file_df = input$user_file,
              crs_param = input$custom_crs,
              walk_speed_kmh = input$param_speed %||% 4.5,
              repair = isTRUE(input$param_repair),
              planarize = isTRUE(input$param_planarize %||% TRUE),
              snap_tolerance_m = as.numeric(input$param_snap_tol %||% 2.0),
              keep_components = input$param_components %||% "all"
            )
            shiny::incProgress(0.7, detail = if (current_lang() == "en") "Done" else "Listo")
            current_net(res$network)
            network_meta(res)
            network_error(NULL)
          }, error = function(e) {
            network_error(e$message)
            current_net(NULL)
            network_meta(NULL)
          })
        })
      } else {
        # Datasets empaquetados
        spd <- input$param_speed %||% 4.5
        rep <- isTRUE(input$param_repair)
        plan <- isTRUE(input$param_planarize %||% TRUE)
        snap_tol <- as.numeric(input$param_snap_tol %||% 2.0)
        comps <- input$param_components %||% "all"

        raw_data <- switch(city,
          "cusco" = streets_cusco,
          "lima" = streets_lima,
          "arequipa" = streets_arequipa,
          streets_cusco
        )

        net <- walk_build_network(
          data = raw_data,
          walk_speed_kmh = spd,
          repair = rep,
          planarize = plan,
          snap_tolerance_m = snap_tol,
          keep_components = comps,
          drop_classes = character(0),
          verbose = FALSE
        )

        current_net(net)
        network_meta(list(
          format = "Dataset integrado",
          target_file = paste0("streets_", city),
          raw_features = nrow(raw_data),
          crs_note = sprintf("EPSG:%s", sf::st_crs(raw_data)$epsg),
          epsg = sf::st_crs(raw_data)$epsg,
          planarize = plan,
          snap_tolerance_m = snap_tol
        ))
        network_error(NULL)
      }
    }) |> shiny::bindEvent(
      input$city_choice,
      input$user_file,
      input$custom_crs,
      input$param_speed,
      input$param_repair,
      input$param_planarize,
      input$param_snap_tol,
      input$param_components,
      ignoreInit = FALSE
    )

    # Reset reactive states on network load
    shiny::observeEvent(current_net(), {
      reach_res(NULL)
      iso_origin_coords(NULL)
      iso_res(NULL)
      route_pt_a(NULL)
      route_pt_b(NULL)
      route_res(NULL)
      bw_sim_res(NULL)
      scen_res(NULL)
      shiny::updateSelectizeInput(session, "scen_edge_select", choices = NULL, selected = character(0))
    }, ignoreInit = TRUE)

    # Active WGS84 edges for MapLibre rendering
    net_edges_4326 <- shiny::reactive({
      net <- current_net()
      shiny::req(net)
      sf::st_transform(net$edges, 4326)
    })

    # Network status badge in sidebar
    output$network_status_badge <- shiny::renderUI({
      err <- network_error()
      is_en <- current_lang() == "en"

      if (!is.null(err)) {
        return(shiny::tags$div(
          class = "alert alert-danger p-2 mt-2",
          style = "font-size: 0.85rem;",
          shiny::tags$strong(if (is_en) "Network loading error: " else "Error al cargar red: "), err,
          shiny::tags$div(
            style = "font-size: 0.78rem; margin-top: 4px;",
            if (is_en) {
              "Ensure the ZIP archive contains a .shp (with .dbf and .shx), or is a GeoPackage (.gpkg) with line geometries."
            } else {
              "Aseg\u00farate de que el archivo ZIP contenga un .shp (con .dbf y .shx), o sea un GeoPackage (.gpkg) con geometr\u00edas lineales."
            }
          )
        ))
      }

      if (input$city_choice == "custom" && is.null(input$user_file)) {
        return(shiny::tags$div(
          class = "alert alert-warning p-2 mt-2",
          style = "font-size: 0.85rem;",
          shiny::tags$strong(if (is_en) "Awaiting dataset: " else "Esperando archivo: "),
          if (is_en) "Upload your GeoPackage (.gpkg), Shapefile (.zip), or GeoJSON from the sidebar." else "Sube tu GeoPackage (.gpkg), Shapefile (.zip) o GeoJSON en el panel lateral."
        ))
      }

      net <- current_net()
      if (is.null(net)) return(NULL)

      meta <- network_meta()
      crs_info <- if (!is.null(meta$crs_note) && nzchar(meta$crs_note)) {
        paste0(" | ", meta$crs_note)
      } else {
        ""
      }

      raw_n <- meta$raw_features
      curr_n <- nrow(net$edges)
      n_omitted <- if (!is.null(raw_n) && raw_n > curr_n) raw_n - curr_n else 0

      comp_txt <- if (!is.null(net$total_components) && net$total_components > 1) {
        if (n_omitted > 0) {
          if (is_en) sprintf(" | %d disconnected islands excluded", n_omitted) else sprintf(" | %d islas/tramos desconectados excluidos", n_omitted)
        } else {
          if (is_en) sprintf(" (%d connected components)", net$total_components) else sprintf(" (%d componentes/islas conexas)", net$total_components)
        }
      } else {
        ""
      }

      shiny::tags$div(
        class = "alert alert-success p-2 mt-2",
        style = "font-size: 0.85rem;",
        shiny::tags$strong(if (is_en) "Active Network: " else "Red cargada: "),
        sprintf(if (is_en) "%s nodes | %s edges (%.1f km)%s%s" else "%s nodos | %s tramos (%.1f km)%s%s",
          nrow(net$nodes), curr_n, sum(net$edges$length_m) / 1000, comp_txt, crs_info)
      )
    })

    # Download handler for active network GeoJSON
    output$dl_net_edges <- shiny::downloadHandler(
      filename = function() {
        paste0("red_activa_walkability_", input$city_choice, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        edges_wgs <- net_edges_4326()
        shiny::req(edges_wgs)
        sf::st_write(edges_wgs, file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # -------------------------------------------------------------
    # 2. PESTANA: ALCANCE PEATONAL (REACH)
    # -------------------------------------------------------------
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      t_val <- as.numeric(input$reach_time_min %||% 10)
      r <- walk_compute_reach(net, time_min = t_val)
      reach_res(r)
    }) |> shiny::bindEvent(input$btn_calc_reach, current_net(), ignoreInit = FALSE)

    output$dl_reach_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("alcance_peatonal_", input$reach_time_min, "min_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        r <- reach_res()
        if (is.null(r)) {
          shiny::showNotification(.app_i18n("notif_reach_before_dl", current_lang()), type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(r$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    output$reach_stat_mean <- shiny::renderText({
      r <- reach_res()
      if (is.null(r)) return("--")
      sprintf("%.2f km", r$summary$mean_reach_km)
    })

    output$reach_stat_max <- shiny::renderText({
      r <- reach_res()
      if (is.null(r)) return("--")
      sprintf("%.2f km", r$summary$max_reach_km)
    })

    output$map_reach <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)
      is_en <- current_lang() == "en"

      r <- reach_res()
      if (!is.null(r) && !is.null(r$edges$reachable_length_km)) {
        lens <- r$edges$reachable_length_km
        edges_wgs$reachable_length_km <- lens
        min_v <- stats::quantile(lens, 0.05, na.rm = TRUE)
        max_v <- stats::quantile(lens, 0.95, na.rm = TRUE)
        if (is.na(min_v) || is.na(max_v) || max_v <= min_v) max_v <- (min_v %||% 0) + 1
        norm_v <- pmin(pmax((lens - min_v) / (max_v - min_v), 0), 1)
        norm_v[is.na(norm_v)] <- 0
        pal <- scales::col_numeric("viridis", domain = c(0, 1))
        edges_wgs$color <- pal(norm_v)
        lens_clean <- ifelse(is.na(lens), 0, lens)
        edges_wgs$tooltip_text <- sprintf(
          .app_i18n("reach_tooltip_calc", current_lang()),
          lens_clean, seq_len(nrow(edges_wgs))
        )
      } else {
        edges_wgs$color <- "#0A9396"
        edges_wgs$tooltip_text <- sprintf(
          .app_i18n("reach_tooltip_base", current_lang()),
          seq_len(nrow(edges_wgs)), edges_wgs$length_m
        )
      }

      m <- mapgl::maplibre(
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

      if (!is.null(r) && !is.null(r$edges$reachable_length_km)) {
        t_val <- as.numeric(input$reach_time_min %||% 10)
        min_km <- round(suppressWarnings(min(lens, na.rm = TRUE)), 2)
        max_km <- round(suppressWarnings(max(lens, na.rm = TRUE)), 2)
        if (is.infinite(min_km) || is.na(min_km)) min_km <- 0.0
        if (is.infinite(max_km) || is.na(max_km) || max_km <= min_km) max_km <- min_km + 1.0
        mid_km <- round((min_km + max_km) / 2, 2)

        m <- m |> mapgl::add_continuous_legend(
          legend_title = sprintf(.app_i18n("reach_legend_continuous", current_lang()), as.integer(t_val)),
          values = c(
            sprintf("%.1f km", min_km),
            sprintf("%.1f km", mid_km),
            sprintf("%.1f km", max_km)
          ),
          colors = c("#440154", "#3b528b", "#21908d", "#5dc863", "#fde725"),
          position = "bottom-right"
        )
      } else {
        m <- m |> mapgl::add_categorical_legend(
          legend_title = .app_i18n("reach_legend_title", current_lang()),
          values = c(.app_i18n("reach_legend_base", current_lang())),
          colors = c("#0A9396"),
          patch_shape = "line",
          position = "bottom-right"
        )
      }

      m
    })

    # -------------------------------------------------------------
    # 3. PESTANA: ISOCRONAS (ISOCHRONES)
    # -------------------------------------------------------------
    shiny::observeEvent(input$map_iso_click, {
      click <- input$map_iso_click
      if (!is.null(click$lng) && !is.null(click$lat)) {
        iso_origin_coords(c(click$lng, click$lat))
      }
    })

    output$iso_origin_label <- shiny::renderText({
      coords <- iso_origin_coords()
      if (is.null(coords)) {
        .app_i18n("iso_origin_default", current_lang())
      } else {
        sprintf(.app_i18n("iso_origin_fixed", current_lang()), coords[1], coords[2])
      }
    })

    # Helper reactive to extract cutoffs from either custom text or selectize
    active_iso_cutoffs <- shiny::reactive({
      custom_txt <- trimws(input$iso_custom_times_text %||% "")
      if (nzchar(custom_txt)) {
        matches <- regmatches(custom_txt, gregexpr("[0-9]+(?:\\.[0-9]+)?", custom_txt))[[1]]
        nums <- as.numeric(matches)
        valid_nums <- sort(unique(nums[!is.na(nums) & nums > 0]))
        if (length(valid_nums) > 0) return(valid_nums)
      }
      sel <- sort(unique(as.numeric(input$iso_cutoffs)))
      if (length(sel) == 0) c(5, 10, 15) else sel
    })

    # Real-time preview badge of the active cutoffs to be computed
    output$iso_times_preview <- shiny::renderUI({
      cuts <- active_iso_cutoffs()
      is_custom <- nzchar(trimws(input$iso_custom_times_text %||% ""))
      is_en <- current_lang() == "en"
      src_label <- if (is_en) {
        if (is_custom) "Detected cutoffs:" else "Selected cutoffs:"
      } else {
        if (is_custom) "Tiempos detectados:" else "Tiempos seleccionados:"
      }

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
        if (nrow(giant_nodes) == 0) giant_nodes <- net$nodes
        if (nrow(giant_nodes) == 0) return()
        pt_origin <- sf::st_coordinates(giant_nodes)[1, 1:2]
      } else {
        pt_wgs <- sf::st_sfc(sf::st_point(coords), crs = 4326)
        pt_proj <- sf::st_transform(pt_wgs, sf::st_crs(net$nodes))
        pt_origin <- sf::st_coordinates(pt_proj)[1, 1:2]
      }

      meth <- input$iso_method %||% "concave"
      do_rings <- isTRUE(input$iso_rings)

      tryCatch({
        iso <- walk_isochrone(
          network = net,
          origin = pt_origin,
          time_min = cutoffs,
          method = meth,
          rings = do_rings
        )
        iso_res(iso)
      }, error = function(e) {
        iso_res(NULL)
      })
    }) |> shiny::bindEvent(input$btn_calc_iso, current_net(), ignoreInit = FALSE)

    output$dl_iso_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("isocronas_walkability_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        iso <- iso_res()
        if (is.null(iso)) {
          shiny::showNotification(.app_i18n("notif_iso_before_dl", current_lang()), type = "warning")
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
      if (current_lang() == "en") {
        names(res_tab) <- c("Time Band", "Cutoff (min)", "Area (km\u00b2)", "Accessible Network (km)", "Edges")[seq_along(cols)]
      } else {
        names(res_tab) <- c("Banda Temporal", "L\u00edmite (min)", "\u00c1rea (km\u00b2)", "Red Alcanzable (km)", "Tramos")[seq_along(cols)]
      }
      res_tab
    })

    output$map_iso <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)
      is_en <- current_lang() == "en"

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
        band_colors <- c("#2A9D8F", "#E76F51", "#7209B7", "#005F73", "#E9D8A6")
        polys_wgs$color <- band_colors[(seq_len(nrow(polys_wgs)) - 1) %% length(band_colors) + 1]

        if (is_en) {
          polys_wgs$popup_text <- sprintf("<strong>Band: %s</strong><br>Area: %.2f km\u00b2<br>Network: %.2f km",
            polys_wgs$interval %||% paste(polys_wgs$time_min, "min"),
            polys_wgs$area_km2,
            polys_wgs$network_length_km)
        } else {
          polys_wgs$popup_text <- sprintf("<strong>Banda: %s</strong><br>\u00c1rea: %.2f km\u00b2<br>Red: %.2f km",
            polys_wgs$interval %||% paste(polys_wgs$time_min, "min"),
            polys_wgs$area_km2,
            polys_wgs$network_length_km)
        }

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
    # 4. PESTANA: RUTEO & CIRCUIDAD (ROUTING)
    # -------------------------------------------------------------
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
      if (nrow(nodes_proj) < 20) nodes_proj <- net$nodes
      n_cand <- nrow(nodes_proj)
      if (n_cand >= 2) {
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

    output$dl_route_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("ruta_optima_caminata_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        r <- route_res()
        if (is.null(r) || is.null(r$path_sf)) {
          shiny::showNotification(.app_i18n("notif_route_before_dl", current_lang()), type = "warning")
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

      # Usar isolate para no re-renderizar el mapa base ni resetear el zoom
      # al fijar puntos o calcular la ruta
      pa <- shiny::isolate(route_pt_a())
      pb <- shiny::isolate(route_pt_b())

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

      r <- shiny::isolate(route_res())
      if (!is.null(r) && !is.null(r$path_sf)) {
        path_wgs <- sf::st_transform(r$path_sf, 4326)
        path_wgs$tooltip_text <- sprintf(
          .app_i18n("route_tooltip", current_lang()),
          r$distance_m, r$time_min, r$circuity
        )

        m <- m |>
          mapgl::add_line_layer(
            id = "route_path_casing",
            source = path_wgs,
            line_color = "#FFFFFF",
            line_width = 7.5,
            line_opacity = 0.95
          ) |>
          mapgl::add_line_layer(
            id = "route_path",
            source = path_wgs,
            line_color = "#E63946",
            line_width = 5.0,
            line_opacity = 1.0,
            tooltip = "tooltip_text"
          )
      }

      # Leyenda cartografica de ruteo
      m |> mapgl::add_categorical_legend(
        legend_title = .app_i18n("route_legend_title", current_lang()),
        values = c(.app_i18n("route_legend_path", current_lang()), .app_i18n("route_legend_base", current_lang())),
        colors = c("#E63946", "#475569"),
        position = "bottom-right"
      )
    })

    # Actualizaciones reactivas de marcadores y ruta via proxy
    shiny::observeEvent(route_pt_a(), {
      proxy <- mapgl::maplibre_proxy("map_route")
      tryCatch(mapgl::clear_layer(proxy, "marker_a"), error = function(e) NULL)
      pa <- route_pt_a()
      if (!is.null(pa)) {
        pt_a_sf <- sf::st_sf(label = "Origen (A)", geometry = sf::st_sfc(sf::st_point(pa), crs = 4326))
        proxy |> mapgl::add_circle_layer(
          id = "marker_a",
          source = pt_a_sf,
          circle_color = "#10B981",
          circle_radius = 9,
          circle_stroke_width = 2.5,
          circle_stroke_color = "#FFFFFF"
        )
      }
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    shiny::observeEvent(route_pt_b(), {
      proxy <- mapgl::maplibre_proxy("map_route")
      tryCatch(mapgl::clear_layer(proxy, "marker_b"), error = function(e) NULL)
      pb <- route_pt_b()
      if (!is.null(pb)) {
        pt_b_sf <- sf::st_sf(label = "Destino (B)", geometry = sf::st_sfc(sf::st_point(pb), crs = 4326))
        proxy |> mapgl::add_circle_layer(
          id = "marker_b",
          source = pt_b_sf,
          circle_color = "#F97316",
          circle_radius = 9,
          circle_stroke_width = 2.5,
          circle_stroke_color = "#FFFFFF"
        )
      }
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    shiny::observeEvent(route_res(), {
      proxy <- mapgl::maplibre_proxy("map_route")
      tryCatch({
        mapgl::clear_layer(proxy, "route_path_casing")
        mapgl::clear_layer(proxy, "route_path")
      }, error = function(e) NULL)

      r <- route_res()
      if (!is.null(r) && !is.null(r$path_sf)) {
        path_wgs <- sf::st_transform(r$path_sf, 4326)
        path_wgs$tooltip_text <- sprintf(
          .app_i18n("route_tooltip", current_lang()),
          r$distance_m, r$time_min, r$circuity
        )

        proxy |>
          mapgl::add_line_layer(
            id = "route_path_casing",
            source = path_wgs,
            line_color = "#FFFFFF",
            line_width = 7.5,
            line_opacity = 0.95
          ) |>
          mapgl::add_line_layer(
            id = "route_path",
            source = path_wgs,
            line_color = "#E63946",
            line_width = 5.0,
            line_opacity = 1.0,
            tooltip = "tooltip_text"
          )
      }
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    # -------------------------------------------------------------
    # 5. PESTANA: MORFOLOGIA URBANA (MORPHOLOGY)
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
        paste0("morfologia_cruces_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        m <- morph_res()
        if (is.null(m) || is.null(m$nodes)) {
          shiny::showNotification(.app_i18n("notif_morph_no_nodes", current_lang()), type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(m$nodes, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
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
        nodes_filtered$type_label <- sprintf(.app_i18n("morph_tooltip", current_lang()), nodes_filtered$junction_type, nodes_filtered$degree)
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
        legend_title = .app_i18n("morph_legend_title", current_lang()),
        values = c(
          .app_i18n("morph_legend_v1", current_lang()),
          .app_i18n("morph_legend_v3", current_lang()),
          .app_i18n("morph_legend_v4", current_lang())
        ),
        colors = c("#E63946", "#457B9D", "#2A9D8F"),
        patch_shape = "circle",
        position = "bottom-right"
      )
    })

    # -------------------------------------------------------------
    # 6. PESTANA: ESCENARIOS E INTERMEDIACION (SCENARIOS & BETWEENNESS)
    # -------------------------------------------------------------
    calc_base_betweenness <- function() {
      net <- current_net()
      shiny::req(net)
      is_en <- current_lang() == "en"

      if (!requireNamespace("igraph", quietly = TRUE)) {
        shiny::showNotification(
          .app_i18n("notif_bw_need_igraph", current_lang()),
          type = "warning",
          duration = 5
        )
        bw_base_res(NULL)
        return(NULL)
      }
      snap_r <- as.numeric(input$scen_snap_radius %||% 0)
      cut_r <- as.numeric(input$scen_analysis_radius %||% 0)
      tryCatch({
        shiny::withProgress(message = if (is_en) "Computing baseline street betweenness..." else "Calculando intermediaci\u00f3n de red base...", value = 0.3, {
          b <- walk_betweenness(
            network = net,
            snap_tolerance_m = snap_r,
            radius_m = if (cut_r > 0) cut_r else NULL
          )
          shiny::incProgress(0.7, detail = if (is_en) "Complete" else "Finalizado")
          bw_base_res(b)
          bw_sim_res(NULL)
          scen_res(NULL)
        })
      }, error = function(e) {
        shiny::showNotification(paste(if (is_en) "Betweenness notice:" else "Aviso en intermediaci\u00f3n:", e$message), type = "warning")
        bw_base_res(NULL)
      })
    }

    # Automatically compute baseline betweenness on network load ONLY if igraph is available
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      if (requireNamespace("igraph", quietly = TRUE)) {
        calc_base_betweenness()
      } else {
        bw_base_res(NULL)
      }
    }) |> shiny::bindEvent(current_net(), ignoreInit = FALSE)

    # Recalculate baseline when user explicitly requests
    shiny::observeEvent(input$btn_recalc_bw_base, {
      calc_base_betweenness()
      shiny::showNotification(.app_i18n("notif_bw_recalc_ok", current_lang()), type = "message")
    })

    # Populate edge choices when network or betweenness updates
    shiny::observe({
      net <- current_net()
      shiny::req(net)
      edges <- net$edges
      n_edges <- nrow(edges)
      is_en <- current_lang() == "en"

      if (n_edges > 0) {
        b_base <- bw_base_res()
        choices_vec <- as.character(seq_len(n_edges))
        names(choices_vec) <- vapply(seq_len(n_edges), function(i) {
          nm <- if ("name" %in% names(edges) && !is.na(edges$name[i]) && nzchar(trimws(edges$name[i]))) {
            edges$name[i]
          } else {
            if (is_en) paste0("Segment #", i) else paste0("Tramo #", i)
          }
          hw <- if ("highway" %in% names(edges) && !is.na(edges$highway[i])) edges$highway[i] else "street"
          bw_str <- if (!is.null(b_base) && !is.null(b_base$edges$betweenness[i])) {
            sprintf(if (is_en) " | Betweenness: %.0f" else " | Intermed: %.0f", b_base$edges$betweenness[i])
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

    # Sample random edges button
    shiny::observeEvent(input$btn_sample_random, {
      net <- current_net()
      shiny::req(net)
      n_edges <- nrow(net$edges)
      n_pick <- min(as.integer(input$scen_random_n %||% 3), n_edges)
      if (n_pick > 0) {
        sampled <- as.character(sample(seq_len(n_edges), n_pick))
        shiny::updateSelectizeInput(session, "scen_edge_select", selected = sampled)
      }
    })

    # Pick top bottleneck button
    shiny::observeEvent(input$btn_pick_top_bottleneck, {
      b <- bw_base_res()
      shiny::req(b)
      is_en <- current_lang() == "en"
      if (nrow(b$top_bottlenecks) > 0) {
        top_id <- as.character(b$top_bottlenecks$`# ID`[1])
        curr <- as.character(input$scen_edge_select %||% character(0))
        new_sel <- unique(c(curr, top_id))
        shiny::updateSelectizeInput(session, "scen_edge_select", selected = new_sel)
        shiny::showNotification(
          if (is_en) sprintf("Selected top critical bottleneck #%s (%s)", top_id, b$top_bottlenecks$Nombre[1]) else sprintf("Se seleccion\u00f3 el cuello de botella cr\u00edtico #%s (%s)", top_id, b$top_bottlenecks$Nombre[1]),
          type = "message"
        )
      }
    })

    # Info summary of selected edges
    output$scen_selected_info <- shiny::renderUI({
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      net <- current_net()
      is_en <- current_lang() == "en"

      if (length(sel) == 0 || is.null(net)) {
        return(shiny::tags$p(
          style = "font-size: 0.8rem; color: #6c757d; font-style: italic; margin-top: 4px;",
          if (is_en) "No segments selected. Click on the map or search above." else "Ning\u00fan tramo seleccionado. Haz clic en el mapa o b\u00fascalo arriba."
        ))
      }
      valid_sel <- sel[sel >= 1 & sel <= nrow(net$edges)]
      total_m <- sum(net$edges$length_m[valid_sel], na.rm = TRUE)
      shiny::tags$div(
        class = "alert alert-info py-1 px-2 my-2",
        style = "font-size: 0.82rem;",
        shiny::tags$strong(if (is_en) sprintf("%d segment(s) marked", length(valid_sel)) else sprintf("%d tramo(s) marcado(s)", length(valid_sel))),
        shiny::tags$span(sprintf(" \u2014 %.1f m (%.2f km)", total_m, total_m / 1000))
      )
    })

    # Run simulation on user-selected segments
    shiny::observeEvent(input$btn_sim_scenario, {
      net <- current_net()
      shiny::req(net)
      is_en <- current_lang() == "en"

      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      valid_edges <- sel[sel >= 1 & sel <= nrow(net$edges)]
      if (length(valid_edges) == 0) {
        shiny::showNotification(.app_i18n("notif_bw_select_edge", current_lang()), type = "warning")
        return()
      }
      if (!requireNamespace("igraph", quietly = TRUE)) {
        shiny::showNotification(.app_i18n("notif_bw_need_igraph", current_lang()), type = "warning")
        return()
      }
      snap_r <- as.numeric(input$scen_snap_radius %||% 0)
      cut_r <- as.numeric(input$scen_analysis_radius %||% 0)
      tryCatch({
        shiny::withProgress(message = if (is_en) "Simulating street closures..." else "Simulando cierres viales...", value = 0.2, {
          shiny::incProgress(0.3, detail = if (is_en) "Recalculating shortest paths and betweenness shift..." else "Recalculando rutas y redistribuci\u00f3n de intermediaci\u00f3n...")
          sim <- walk_scenario_betweenness(
            network = net,
            closed_edges = valid_edges,
            snap_tolerance_m = snap_r,
            radius_m = if (cut_r > 0) cut_r else NULL,
            verbose = FALSE
          )
          bw_sim_res(sim)
          shiny::incProgress(0.3, detail = if (is_en) "Evaluating pedestrian accessibility shift..." else "Evaluando variaci\u00f3n de accesibilidad peatonal...")
          mod_net <- sim$mod_network
          comp <- walk_compare_scenarios(base = net, scenario = mod_net, time_min = 5.0, verbose = FALSE)
          scen_res(list(comp = comp, closed_edges = valid_edges, mod_net = mod_net))
          shiny::updateRadioButtons(session, "scen_view_mode", selected = "sim_bw")
          shiny::incProgress(0.2, detail = if (is_en) "Done" else "Listo")
        })
      }, error = function(e) {
        shiny::showNotification(sprintf(.app_i18n("notif_bw_error", current_lang()), e$message), type = "error")
      })
    })

    # Download handler for Baseline Betweenness GeoJSON
    output$dl_betweenness_base_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("intermediacion_base_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        b <- bw_base_res()
        if (is.null(b) || is.null(b$edges)) {
          shiny::showNotification(.app_i18n("notif_bw_no_base", current_lang()), type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(b$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # Download handler for Simulation Closures GeoJSON
    output$dl_betweenness_sim_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("simulacion_intermediacion_cierres_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        s <- bw_sim_res()
        if (is.null(s) || is.null(s$edges)) {
          shiny::showNotification(.app_i18n("notif_bw_sim_before_dl", current_lang()), type = "warning")
          return()
        }
        sf::st_write(sf::st_transform(s$edges, 4326), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # Download handler for Resulting Modified Network GeoJSON
    output$dl_scen_sf <- shiny::downloadHandler(
      filename = function() {
        paste0("red_modificada_post_cierre_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".geojson")
      },
      content = function(file) {
        s <- scen_res()
        if (is.null(s) || is.null(s$mod_net)) {
          shiny::showNotification(.app_i18n("notif_bw_net_before_dl", current_lang()), type = "warning")
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
      is_en <- current_lang() == "en"
      if (is.null(s)) {
        b <- bw_base_res()
        if (is.null(b)) return("--")
        sprintf(if (is_en) "%.0f (baseline mean)" else "%.0f (media base)", b$summary$mean_betweenness)
      } else {
        sprintf("%.0f \u2192 %.0f", s$summary$base_mean, s$summary$sim_mean)
      }
    })

    # Tables
    output$table_top_diverted <- shiny::renderTable({
      s <- bw_sim_res()
      is_en <- current_lang() == "en"
      if (is.null(s) || nrow(s$top_diverted) == 0) {
        msg <- if (is_en) "Run a simulation to identify which streets assume the highest betweenness due to closures." else "Ejecuta una simulaci\u00f3n para identificar qu\u00e9 v\u00edas asumen mayor intermediaci\u00f3n producto del cierre."
        status_col <- if (is_en) "Status" else "Estado"
        df <- data.frame(val = msg, stringsAsFactors = FALSE)
        names(df) <- status_col
        return(df)
      }
      tab <- s$top_diverted
      if (is_en) {
        names(tab) <- c("Segment ID", "Street / Name", "Base Betweenness", "Sim. Betweenness", "Increase (Delta)", "Relative Increase (%)")[seq_along(names(tab))]
      }
      tab
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    output$table_closed_edges <- shiny::renderTable({
      net <- current_net()
      sel <- as.integer(input$scen_edge_select)
      sel <- sel[!is.na(sel)]
      is_en <- current_lang() == "en"
      status_col <- if (is_en) "Status" else "Estado"

      if (length(sel) == 0 || is.null(net)) {
        msg <- if (is_en) "No segments selected. Click on the map or search above." else "No hay tramos seleccionados. Haz clic en el mapa o b\u00fascalos en el buscador superior."
        df <- data.frame(val = msg, stringsAsFactors = FALSE)
        names(df) <- status_col
        return(df)
      }
      valid_sel <- sel[sel >= 1 & sel <= nrow(net$edges)]
      if (length(valid_sel) == 0) {
        df <- data.frame(val = if (is_en) "Invalid segments." else "Tramos inv\u00e1lidos.", stringsAsFactors = FALSE)
        names(df) <- status_col
        return(df)
      }
      sub_edges <- net$edges[valid_sel, , drop = FALSE]
      b_base <- bw_base_res()
      names_col <- if ("name" %in% names(sub_edges)) {
        v <- sub_edges$name
        ifelse(is.na(v) | v == "", if (is_en) "(Unnamed)" else "(Sin nombre)", v)
      } else {
        if (is_en) paste0("Segment #", valid_sel) else paste0("Tramo #", valid_sel)
      }
      type_col <- if ("highway" %in% names(sub_edges)) {
        v <- sub_edges$highway
        ifelse(is.na(v), if (is_en) "street" else "v\u00eda", v)
      } else {
        if (is_en) "street" else "v\u00eda"
      }
      bw_col <- if (!is.null(b_base) && !is.null(b_base$edges$betweenness)) {
        round(b_base$edges$betweenness[valid_sel], 1)
      } else {
        rep(NA_real_, length(valid_sel))
      }

      if (is_en) {
        data.frame(
          `# ID` = valid_sel,
          Name = names_col,
          Type = type_col,
          `Length (m)` = round(sub_edges$length_m, 1),
          `Base Betweenness` = bw_col,
          check.names = FALSE
        )
      } else {
        data.frame(
          `# ID` = valid_sel,
          Nombre = names_col,
          Tipo = type_col,
          `Longitud (m)` = round(sub_edges$length_m, 1),
          `Intermed. Base` = bw_col,
          check.names = FALSE
        )
      }
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    # Render MapLibre map for Scenarios
    output$map_scenarios <- mapgl::renderMaplibre({
      edges_wgs <- net_edges_4326()
      shiny::req(edges_wgs)
      bb <- sf::st_bbox(edges_wgs)
      is_en <- current_lang() == "en"

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
          if (is_en) {
            b_edges_wgs$tooltip_text <- sprintf(
              "<strong>%s</strong> [#%s]<br>Type: %s | Length: %.1fm<br>Betweenness: %.0f (Norm: %.1f)<br>Percentile: %.1f%% (%s)<br><em>Click to select/unselect for closure</em>",
              if ("name" %in% names(b_edges_wgs)) ifelse(is.na(b_edges_wgs$name) | b_edges_wgs$name == "", "(Unnamed)", b_edges_wgs$name) else paste0("Segment #", b_edges_wgs$edge_id),
              b_edges_wgs$edge_id,
              if ("highway" %in% names(b_edges_wgs)) ifelse(is.na(b_edges_wgs$highway), "street", b_edges_wgs$highway) else "street",
              b_edges_wgs$length_m,
              b_edges_wgs$betweenness,
              b_edges_wgs$betweenness_norm,
              b_edges_wgs$betweenness_pctl,
              b_edges_wgs$bottleneck_class
            )
          } else {
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
          }

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
          marked_wgs$tooltip_text <- if (is_en) paste0("Segment #", sel, " [Marked for closure]") else paste0("Tramo #", sel, " [Marcado para clausura]")
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
          legend_title = if (is_en) "Baseline Betweenness (Bottlenecks)" else "Intermediaci\u00f3n Base (Cuellos de Botella)",
          values = if (is_en) {
            c("Critical (Top 10% - Bottleneck)", "High (Top 25% - Main Connector)", "Medium (Secondary Connector)", "Low (Local / Capillary Flow)", "Marked for Closure")
          } else {
            c("Cr\u00edtico (Top 10% - Cuello de Botella)", "Alto (Top 25% - Conector Principal)", "Medio (Conector Secundario)", "Bajo (Tr\u00e1fico Local / Capilar)", "Marcado para Clausura")
          },
          colors = c("#D90429", "#F77F00", "#FCBF49", "#457B9D", "#111827"),
          circular_patches = FALSE,
          position = "bottom-right"
        )

      } else if (mode == "sim_bw") {
        # Visualizing simulation post-closure betweenness
        sim_edges_wgs <- sf::st_transform(b_sim$edges, 4326)
        open_wgs <- sim_edges_wgs[!sim_edges_wgs$is_closed, ]
        closed_wgs <- sim_edges_wgs[sim_edges_wgs$is_closed, ]

        if (is_en) {
          open_wgs$tooltip_text <- sprintf(
            "<strong>%s</strong> [#%s]<br>Type: %s | Length: %.1fm<br>Post-Closure Betweenness: %.0f (Norm: %.1f)<br>Baseline: %.0f (\u0394: %+.0f)<br>Status: %s",
            if ("name" %in% names(open_wgs)) ifelse(is.na(open_wgs$name) | open_wgs$name == "", "(Unnamed)", open_wgs$name) else paste0("Segment #", open_wgs$edge_id),
            open_wgs$edge_id,
            if ("highway" %in% names(open_wgs)) ifelse(is.na(open_wgs$highway), "street", open_wgs$highway) else "street",
            open_wgs$length_m,
            open_wgs$betweenness_sim,
            open_wgs$betweenness_sim_norm,
            open_wgs$betweenness_base,
            open_wgs$delta_betweenness,
            open_wgs$status
          )
        } else {
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
        }

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
          closed_wgs$tooltip_text <- if (is_en) paste0("Segment #", closed_wgs$edge_id, " [Closed / Pedestrianized]") else paste0("Tramo #", closed_wgs$edge_id, " [Clausurado / Peatonalizado]")
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
          legend_title = if (is_en) "Post-Closure Betweenness" else "Intermediaci\u00f3n Post-Cierre",
          values = if (is_en) {
            c("Critical Post-Closure (Top 10%)", "High Post-Closure (Top 25%)", "Medium Post-Closure", "Low Post-Closure", "Closed / Pedestrianized")
          } else {
            c("Cr\u00edtico Post-Cierre (Top 10%)", "Alto Post-Cierre (Top 25%)", "Medio Post-Cierre", "Bajo Post-Cierre", "Clausurado / Peatonalizado")
          },
          colors = c("#D90429", "#F77F00", "#FCBF49", "#457B9D", "#111827"),
          patch_shape = "square",
          position = "bottom-right"
        )

      } else {
        # Visualizing delta betweenness (diversions and stress shifts)
        sim_edges_wgs <- sf::st_transform(b_sim$edges, 4326)
        open_wgs <- sim_edges_wgs[!sim_edges_wgs$is_closed, ]
        closed_wgs <- sim_edges_wgs[sim_edges_wgs$is_closed, ]

        if (is_en) {
          open_wgs$tooltip_text <- sprintf(
            "<strong>%s</strong> [#%s]<br>Flow Shift (\u0394): %+.0f<br>Base: %.0f \u2192 Post-Closure: %.0f<br>Status: %s",
            if ("name" %in% names(open_wgs)) ifelse(is.na(open_wgs$name) | open_wgs$name == "", "(Unnamed)", open_wgs$name) else paste0("Segment #", open_wgs$edge_id),
            open_wgs$edge_id,
            open_wgs$delta_betweenness,
            open_wgs$betweenness_base,
            open_wgs$delta_betweenness + open_wgs$betweenness_base,
            open_wgs$status
          )
        } else {
          open_wgs$tooltip_text <- sprintf(
            "<strong>%s</strong> [#%s]<br>Variaci\u00f3n de Flujo (\u0394): %+.0f<br>Base: %.0f \u2192 Post-Cierre: %.0f<br>Estado: %s",
            if ("name" %in% names(open_wgs)) ifelse(is.na(open_wgs$name) | open_wgs$name == "", "(Sin nombre)", open_wgs$name) else paste0("Tramo #", open_wgs$edge_id),
            open_wgs$edge_id,
            open_wgs$delta_betweenness,
            open_wgs$betweenness_base,
            open_wgs$delta_betweenness + open_wgs$betweenness_base,
            open_wgs$status
          )
        }

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
          closed_wgs$tooltip_text <- if (is_en) paste0("Segment #", closed_wgs$edge_id, " [Closed / Pedestrianized]") else paste0("Tramo #", closed_wgs$edge_id, " [Clausurado / Peatonalizado]")
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
          legend_title = if (is_en) "Betweenness Shift (\u0394 Detours)" else "Variaci\u00f3n de Intermediaci\u00f3n (\u0394 Desv\u00edos)",
          values = if (is_en) {
            c("Major Increase (\u0394 Critical Detour)", "Moderate Increase", "Neutral / No Change", "Reduction (\u0394 Relieved)", "Closed")
          } else {
            c("Fuerte Aumento (\u0394 Desv\u00edo Cr\u00edtico)", "Aumento Moderado", "Neutro / Sin Cambio", "Reducci\u00f3n (\u0394 Aliviado)", "Clausurado")
          },
          colors = c("#D90429", "#F77F00", "#94A3B8", "#2A9D8F", "#111827"),
          patch_shape = "square",
          position = "bottom-right"
        )
      }

      m
    })

    # -------------------------------------------------------------
    # 7. GENERADOR DE CODIGO R REPRODUCIBLE (ESTILO ESQUISSE)
    # -------------------------------------------------------------
    shiny::observeEvent(input$code_copied_trigger, {
      shiny::showNotification(.app_i18n("notif_code_copied", current_lang()), type = "message", duration = 3)
    })

    generated_code_reactive <- shiny::reactive({
      city <- input$city_choice
      spd <- input$param_speed
      do_rep <- isTRUE(input$param_repair)
      rep <- if (do_rep) "TRUE" else "FALSE"
      plan <- if (do_rep && isTRUE(input$param_planarize %||% TRUE)) "TRUE" else "FALSE"
      snap_tol <- if (do_rep) as.numeric(input$param_snap_tol %||% 2.0) else 0.0
      filt <- input$code_module_filter
      is_en <- current_lang() == "en"

      header_txt <- if (is_en) {
        c(
          "# ====================================================================",
          "# Pedestrian Walkability Analysis with the {walkability} Package",
          "# Reproducible script generated automatically by the interactive app",
          paste0("# Generation timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
          "# ====================================================================",
          "",
          "library(walkability)",
          "library(sf)",
          ""
        )
      } else {
        c(
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
      }

      # 1. Red
      net_code <- if (is_en) {
        c("# --- 1. Street Network Construction & Topological Repair ---")
      } else {
        c("# --- 1. Construcci\u00f3n y Reparaci\u00f3n Topol\u00f3gica de la Red Vial ---")
      }

      if (city == "custom") {
        meta <- network_meta()
        fname <- if (!is.null(meta$target_file)) meta$target_file else "streets.gpkg"
        epsg_code <- if (!is.null(meta$epsg)) meta$epsg else 32719
        if (is_en) {
          net_code <- c(net_code,
            sprintf("# Dataset uploaded during session: %s (%s)", fname, meta$format %||% "spatial file"),
            sprintf("street_data <- sf::st_read('%s')", fname),
            "# Ensure 2D geometry and projected metric CRS (UTM):",
            "street_data <- sf::st_zm(street_data, drop = TRUE, what = 'ZM')",
            "if (sf::st_is_longlat(street_data)) {",
            sprintf("  street_data <- sf::st_transform(street_data, %d)", epsg_code),
            "}",
            sprintf("net <- walk_build_network(street_data, walk_speed_kmh = %.1f, repair = %s, planarize = %s, snap_tolerance_m = %.1f)", spd, rep, plan, snap_tol)
          )
        } else {
          net_code <- c(net_code,
            sprintf("# Archivo cargado en sesi\u00f3n: %s (%s)", fname, meta$format %||% "archivo espacial"),
            sprintf("datos_calles <- sf::st_read('%s')", fname),
            "# Asegurar geometr\u00eda 2D y proyecci\u00f3n m\u00e9trica (UTM):",
            "datos_calles <- sf::st_zm(datos_calles, drop = TRUE, what = 'ZM')",
            "if (sf::st_is_longlat(datos_calles)) {",
            sprintf("  datos_calles <- sf::st_transform(datos_calles, %d)", epsg_code),
            "}",
            sprintf("net <- walk_build_network(datos_calles, walk_speed_kmh = %.1f, repair = %s, planarize = %s, snap_tolerance_m = %.1f)", spd, rep, plan, snap_tol)
          )
        }
      } else {
        ds_name <- paste0("streets_", city)
        net_code <- c(net_code,
          sprintf("utils::data(%s, package = 'walkability')", ds_name),
          sprintf("net <- walk_build_network(%s, walk_speed_kmh = %.1f, repair = %s, planarize = %s, snap_tolerance_m = %.1f)", ds_name, spd, rep, plan, snap_tol)
        )
      }
      net_code <- c(net_code, "print(net)", "")

      # 2. Reach
      t_reach <- input$reach_time_min
      if (is.null(t_reach)) t_reach <- 10
      reach_code <- if (is_en) {
        c(
          "# --- 2. Pedestrian Reach (10-min Walk Reach / Multi-threaded Rust) ---",
          sprintf("reach <- walk_compute_reach(net, time_min = %.1f)", t_reach),
          "print(reach)",
          "plot(reach)",
          "# sf::st_write(reach$edges, 'pedestrian_reach.geojson', delete_dsn = TRUE)",
          ""
        )
      } else {
        c(
          "# --- 2. Alcance Peatonal (10-min Reach / Rust Multi-hilo) ---",
          sprintf("reach <- walk_compute_reach(net, time_min = %.1f)", t_reach),
          "print(reach)",
          "plot(reach)",
          "# sf::st_write(reach$edges, 'red_alcance_peatonal.geojson', delete_dsn = TRUE)",
          ""
        )
      }

      # 3. Isochrones
      iso_orig <- iso_origin_coords()
      cuts <- active_iso_cutoffs()
      cutoffs_str <- paste(cuts, collapse = ", ")
      method_str <- if (!is.null(input$iso_method)) input$iso_method else "concave"
      rings_str <- if (isTRUE(input$iso_rings)) "TRUE" else "FALSE"

      if (is.null(iso_orig)) {
        iso_orig_line <- if (is_en) {
          "origin_coord <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]"
        } else {
          "origen_coord <- sf::st_coordinates(net$nodes[net$nodes$is_giant, ])[1, 1:2]"
        }
      } else {
        iso_orig_line <- if (is_en) {
          sprintf("origin_coord <- c(%.6f, %.6f)  # Coordinate selected on map", iso_orig[1], iso_orig[2])
        } else {
          sprintf("origen_coord <- c(%.6f, %.6f)  # Coordenada fijada en mapa", iso_orig[1], iso_orig[2])
        }
      }

      iso_code <- if (is_en) {
        c(
          "# --- 3. Multi-cutoff Isochrones (Non-Overlapping Rings) ---",
          iso_orig_line,
          "origin_sf <- sf::st_sfc(sf::st_point(origin_coord), crs = 4326)",
          "origin_proj <- sf::st_transform(origin_sf, sf::st_crs(net$nodes))",
          sprintf("iso <- walk_isochrone(net, origin = sf::st_coordinates(origin_proj)[1, 1:2], time_min = c(%s), method = '%s', rings = %s)",
                  cutoffs_str, method_str, rings_str),
          "print(iso)",
          "plot(iso)",
          "# sf::st_write(iso$polygons, 'multi_isochrones.geojson', delete_dsn = TRUE)",
          ""
        )
      } else {
        c(
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
      }

      # 4. Route
      pa <- route_pt_a()
      pb <- route_pt_b()
      if (is.null(pa) || is.null(pb)) {
        route_setup <- if (is_en) {
          c(
            "coords_giant <- sf::st_coordinates(sf::st_transform(net$nodes[net$nodes$is_giant, ], 4326))",
            "point_a <- coords_giant[1, 1:2]",
            "point_b <- coords_giant[min(50, nrow(coords_giant)), 1:2]"
          )
        } else {
          c(
            "coords_giant <- sf::st_coordinates(sf::st_transform(net$nodes[net$nodes$is_giant, ], 4326))",
            "punto_a <- coords_giant[1, 1:2]",
            "punto_b <- coords_giant[min(50, nrow(coords_giant)), 1:2]"
          )
        }
      } else {
        route_setup <- if (is_en) {
          c(
            sprintf("point_a <- c(%.6f, %.6f)  # Origin", pa[1], pa[2]),
            sprintf("point_b <- c(%.6f, %.6f)  # Destination", pb[1], pb[2])
          )
        } else {
          c(
            sprintf("punto_a <- c(%.6f, %.6f)  # Origen", pa[1], pa[2]),
            sprintf("punto_b <- c(%.6f, %.6f)  # Destino", pb[1], pb[2])
          )
        }
      }

      route_code <- if (is_en) {
        c(
          "# --- 4. Point-to-Point Routing & Circuity Ratio (Dijkstra Min-Heap) ---",
          route_setup,
          "pt_a_proj <- sf::st_transform(sf::st_sfc(sf::st_point(point_a), crs = 4326), sf::st_crs(net$nodes))",
          "pt_b_proj <- sf::st_transform(sf::st_sfc(sf::st_point(point_b), crs = 4326), sf::st_crs(net$nodes))",
          "route <- walk_shortest_path(net, from = sf::st_coordinates(pt_a_proj)[1, 1:2], to = sf::st_coordinates(pt_b_proj)[1, 1:2])",
          "print(route)",
          "plot(route, network = net)",
          "# sf::st_write(route$path_sf, 'optimal_path.geojson', delete_dsn = TRUE)",
          ""
        )
      } else {
        c(
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
      }

      # 5. Morphology
      classes_vec <- paste(input$morph_classes, collapse = ", ")
      if (!nzchar(classes_vec)) classes_vec <- "1, 3, 4"
      morph_code <- if (is_en) {
        c(
          "# --- 5. Urban Morphology & Intersection Density (Node Valence) ---",
          "morph <- walk_intersection_density(net)",
          "print(morph)",
          "plot(morph)",
          sprintf("# Filter by selected degree classes (degrees %s):", classes_vec),
          sprintf("nodes_sel <- morph$nodes[morph$nodes$degree %%in%% c(%s), ]", classes_vec),
          "# sf::st_write(nodes_sel, 'morphology_nodes.geojson', delete_dsn = TRUE)",
          ""
        )
      } else {
        c(
          "# --- 5. Morfolog\u00eda Urbana y Densidad de Cruces (Topolog\u00eda de Nodos) ---",
          "morfologia <- walk_intersection_density(net)",
          "print(morfologia)",
          "plot(morfologia)",
          sprintf("# Filtrar por clases seleccionadas (grados %s):", classes_vec),
          sprintf("nodos_sel <- morfologia$nodes[morfologia$nodes$degree %%in%% c(%s), ]", classes_vec),
          "# sf::st_write(nodos_sel, 'nodos_morfologia_urbana.geojson', delete_dsn = TRUE)",
          ""
        )
      }

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

      scen_code <- if (is_en) {
        c(
          "# --- 6. Betweenness Centrality & Street Closure Simulation ---",
          sprintf("baseline_bw <- walk_betweenness(net, snap_tolerance_m = %s%s)", snap_val, cut_str),
          "print(baseline_bw)",
          "plot(baseline_bw)",
          "",
          "# Simulated street closure and resulting detour shift:",
          sprintf("closed_segments <- %s", sel_edges_str),
          sprintf("sim <- walk_scenario_betweenness(net, closed_edges = closed_segments, snap_tolerance_m = %s%s)", snap_val, cut_str),
          "print(sim)",
          "# Streets bearing the highest load increase due to closures:",
          "head(sim$top_diverted, 5)",
          "# sf::st_write(baseline_bw$edges, 'baseline_betweenness.geojson', delete_dsn = TRUE)",
          "# sf::st_write(sim$edges, 'simulated_betweenness.geojson', delete_dsn = TRUE)",
          ""
        )
      } else {
        c(
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
      }

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
