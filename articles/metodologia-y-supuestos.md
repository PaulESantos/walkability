# Metodología, Algoritmo Dijkstra en Rust y Supuestos del Modelo

## 1. Definición Teórica de la Métrica

Para cualquier intersección o nodo $`v`$ de la red vial, su **isócrona
de 10 minutos** es el conjunto de nodos alcanzables dentro de un
presupuesto de tiempo de 10 minutos ($`T = 600`$ segundos) a una
velocidad de caminata constante:

``` math
R(v) = \{ u : \text{walk\_time}(v \to u) \le 600\text{ s} \}
```

La **longitud de red caminable alcanzable** (*Reachable Walkable Network
Length*) cuantifica la suma de las longitudes físicas de todas las vías
contenidas dentro de dicha isócrona:

``` math
\text{reachable\_length}(v) = \sum_{e \in E} \text{fraction}(e, v) \times \text{length}(e)
```

donde $`\text{fraction}(e, v)`$ es la porción de la arista $`e`$
alcanzable desde el origen $`v`$ dentro del presupuesto de tiempo.

------------------------------------------------------------------------

## 2. La Regla de Crédito Parcial (*Partial-Edge Rule*)

En algoritmos convencionales de isócronas, una arista se incluye de
manera “todo o nada”: o sus dos extremos están dentro de la isócrona o
se descarta. Esto introduce un fuerte sesgo artificial por la
granularidad de digitalización (una calle dividida en muchos tramos
cortos sumaría más que una sola calle larga).

En **`walkability`**, cada arista no dirigida $`(u, v)`$ con tiempo de
viaje $`w`$ y longitud física $`l`$ contribuye con:

``` math
l \times \min(1.0,\, f_u + f_v)
```

donde:
``` math
f_x = \max\left(0,\, \frac{T - \text{dist}(x)}{w}\right)
```

es la fracción de la arista accesible desde el extremo $`x`$. Esta regla
garantiza **invarianza ante la subdivisión geométrica**: dividir o
fusionar tramos de calle no altera el valor total medido.

------------------------------------------------------------------------

## 3. Modelo de Velocidad Peatonal

El paquete utiliza una velocidad constante de diseño peatonal:
``` math
v_{\text{walk}} = 4.5\text{ km/h} \quad (\approx 1.25\text{ m/s})
```

El tiempo de recorrido de cada segmento en segundos se calcula como:
``` math
\text{travel\_time\_s} = \frac{\text{length\_m}}{1.25}
```

Un presupuesto de 10 minutos (600 segundos) equivale a una distancia
máxima teórica de **~750 metros** a lo largo de la red.

------------------------------------------------------------------------

## 4. Implementación del Motor en Rust

El algoritmo de Dijkstra se ejecuta en paralelo en **Rust** (usando
`rayon` y la estructura `CSR` - *Compressed Sparse Row*):

1.  **Reutilización de memoria local:** Cada hilo de ejecución posee
    arrays de trabajo preasignados (`scratch memory`). Las búsquedas
    toman tiempo proporcional al subgrafo alcanzado $`O(k \log k)`$ con
    $`k \ll N`$, evitando reasignar vectores gigantes en cada nodo.
2.  **Colapso de aristas paralelas:** Se conservan las aristas de menor
    tiempo entre cada par de nodos y se eliminan los auto-bucles
    (*self-loops*).
3.  **Componente gigante:** Se utiliza un algoritmo *Union-Find* para
    aislar la componente conexa principal de fragmentos huérfanos.

------------------------------------------------------------------------

## 5. Supuestos y Limitaciones del Modelo

Al interpretar los resultados cartográficos y estadísticos de
caminabilidad, deben considerarse los siguientes supuestos
metodológicos:

1.  **Acera transitable por defecto en vías urbanas:** Los datos
    abiertos (Overture / OSM) no siempre registran con precisión si una
    calle cuenta con acera peatonal continua. El modelo asume
    transitabilidad peatonal en todas las clases secundarias y
    residenciales, excluyendo autopistas (`motorway`) y vías rápidas de
    acceso controlado (`trunk`).
2.  **Exclusión de vías rápidas:** Las autopistas y vías troncales se
    eliminan para evitar que las líneas centrales de carreteras actúen
    como atajos artificiales para peatones.
3.  **Entradas privadas y parqueaderos descartados:** Los accesos de
    servicio vehicular privado (`driveway`, `parking_aisle`) son
    filtrados para no sobrestimar la permeabilidad peatonal.
4.  **Dependencia de cruces digitalizados:** Si dos vías peatonales en
    lados opuestos de una avenida no comparten un punto de conexión o
    paso de cebra digitalizado, la red se modela como fragmentada.
5.  **Barreras físicas y desniveles:** En su configuración bidimensional
    básica, el modelo no discrimina pasos a desnivel o muros sin acceso
    a menos que estén explícitamente etiquetados.
6.  **Velocidad uniforme:** La velocidad de 4.5 km/h no considera
    variaciones demográficas (ancianos, niños) ni condiciones climáticas
    adversas.
