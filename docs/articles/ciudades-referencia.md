# Resultados de Referencia: Curitiba, Maringá y São Paulo

## Comparativa Empírica de Tres Ciudades

A continuación se resumen las métricas de red y los valores de
**longitud alcanzable en 10 minutos a 4.5 km/h** para las tres ciudades
de referencia analizadas en el proyecto.

### 1. Estadísticas de Caminabilidad

| Métrica                       |   Curitiba    |    Maringá    |   São Paulo   |
|:------------------------------|:-------------:|:-------------:|:-------------:|
| **Máximo alcanzado**          |    34.9 km    |    36.0 km    |    35.7 km    |
| **Promedio urbano**           |    15.8 km    |    15.5 km    |    17.1 km    |
| **Mínimo (calle sin salida)** |    0.8 km     |    0.8 km     |    0.8 km     |
| **Rango percentil (5º–95º)**  | 4.6 – 25.9 km | 2.6 – 27.1 km | 5.4 – 26.1 km |

### 2. Dimensiones de la Red Peatonal

| Característica                        |   Curitiba   |  Maringá   |  São Paulo   |
|:--------------------------------------|:------------:|:----------:|:------------:|
| **Segmentos peatonales (post-split)** |   169,886    |   54,672   |   603,797    |
| **Nodos en componente principal**     |   126,847    |   36,195   |   435,573    |
| **Aristas consolidadas**              |   167,419    |   54,045   |   595,251    |
| **Longitud total con buffer (km)**    |  15,353 km   |  8,960 km  |  46,042 km   |
| **Nodos fuera de red principal**      | 2.9% (2,066) | 5.3% (912) | 2.9% (6,871) |

------------------------------------------------------------------------

## Hallazgos Principales

1.  **Topes de caminabilidad convergentes:** Las tres ciudades presentan
    máximos muy cercanos (~35–36 km de red alcanzable en 10 minutos).
    Esto indica centros urbanos densamente entramados con manzanas
    menores a 100 metros o abundante conectividad por pasajes
    peatonales.
2.  **Carácter local de la caminabilidad:** En 10 minutos a pie, una
    persona puede recorrer únicamente entre el **0.08%** (São Paulo) y
    el **0.40%** (Maringá) de la red total de la ciudad.
3.  **Escalas de color recomendadas:** Para visualización cartográfica,
    se aconseja recortar las leyendas entre los percentiles 2% y 98%
    (aproximadamente entre 2 km y 28 km) para evitar distorsiones
    visuales por esquinas periféricas aisladas.
