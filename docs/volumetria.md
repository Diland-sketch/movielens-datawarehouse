# Volumetría — MovieLens 25M

## Fuente de esta información

Todo lo siguiente es **DATO CONFIRMADO por consulta directa** (`COUNT(*)` y funciones nativas `pg_size_pretty`) contra la base de datos `movielens_db` en PostgreSQL 17, ejecutada el 22 de septiembre de 2026. Consultas completas en [`scripts/verificacion_volumetria.sql`](../scripts/verificacion_volumetria.sql).

## Conteo de filas por tabla

| Tabla | Archivo original | Filas |
|---|---|---:|
| calificaciones | ratings.csv | 25.000.095 |
| genoma_puntuaciones | genome-scores.csv | 15.584.448 |
| etiquetas | tags.csv | 1.093.360 |
| peliculas | movies.csv | 62.423 |
| enlaces | links.csv | 62.423 |
| genoma_etiquetas | genome-tags.csv | 1.128 |

**Total de registros en la base de datos: 41.804.777**

## Peso físico en disco por tabla

| Tabla | Datos | Índices | Total |
|---|---:|---:|---:|
| calificaciones | 1244 MB | 0 bytes | 1245 MB |
| genoma_puntuaciones | 658 MB | 0 bytes | 658 MB |
| etiquetas | 62 MB | 0 bytes | 62 MB |
| peliculas | 4736 kB | 1384 kB | 6160 kB |
| enlaces | 2816 kB | 1384 kB | 4232 kB |
| genoma_etiquetas | 56 kB | 40 kB | 128 kB |

**Peso total de `movielens_db`: 1983 MB (~1.94 GB)**

## Observación técnica: por qué solo 3 de las 6 tablas tienen índices

`peliculas`, `enlaces` y `genoma_etiquetas` son las únicas tres tablas declaradas con `PRIMARY KEY` en `database/schema_bronze.sql`. En PostgreSQL, declarar una `PRIMARY KEY` crea automáticamente un índice único asociado — no es algo pedido explícitamente, es un comportamiento del motor. Las otras tres tablas (`calificaciones`, `etiquetas`, `genoma_puntuaciones`) no tienen `PRIMARY KEY` por diseño (carga Bronze cruda, sin restricciones de integridad todavía), por lo tanto **no tienen ningún índice**: cualquier consulta que filtre por `usuario_id` o `pelicula_id` en esas tablas hoy hace un escaneo secuencial completo. Esto es esperado en esta etapa y se resuelve en el diseño del modelo dimensional (Silver/Gold), no antes.

## Observaciones pendientes de investigar

- `peliculas` y `enlaces` tienen exactamente el mismo número de filas (62.423) → indicio de relación 1 a 1 entre película y su enlace externo. **PENDIENTE DE CONFIRMAR** cuando se estudie `links.csv` a fondo (¿hay algún `pelicula_id` sin fila en `enlaces`?).
- `genoma_puntuaciones` (15.584.448 filas) es menor que el máximo teórico `peliculas × genoma_etiquetas` (62.423 × 1.128 = 70.413.624). El README oficial describe el genoma como una "matriz densa", lo cual no cuadra directamente con este conteo. **PENDIENTE DE INVESTIGAR** cuando se estudie `genome-scores.csv` a fondo.

## Estado de la carga

Lo que existe hoy en `movielens_db` es una **carga cruda 1:1 de los 6 CSV originales**, sin transformación. No es aún el modelo dimensional del Data Warehouse — no hay claves subrogadas, no hay dimensión Tiempo, no hay separación formal de hechos y dimensiones. Eso corresponde a una etapa posterior del proyecto.