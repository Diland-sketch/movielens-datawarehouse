# Volumetría — MovieLens 25M

## Fuente de esta información

Todo lo siguiente es **DATO CONFIRMADO por consulta directa** a la base `movielens_db` (PostgreSQL 17). Los conteos se midieron el 22 de septiembre de 2026 y se reconfirmaron el 4 de octubre de 2026 tras mover las tablas al esquema `bronze`. Consultas en [`scripts/verificacion_volumetria.sql`](../scripts/verificacion_volumetria.sql).

## Conteo de filas por tabla

| Tabla | Archivo original | Filas | % del total |
|---|---|---:|---:|
| `bronze.calificaciones` | ratings.csv | 25.000.095 | 59,8 % |
| `bronze.genoma_puntuaciones` | genome-scores.csv | 15.584.448 | 37,3 % |
| `bronze.etiquetas` | tags.csv | 1.093.360 | 2,6 % |
| `bronze.peliculas` | movies.csv | 62.423 | 0,15 % |
| `bronze.enlaces` | links.csv | 62.423 | 0,15 % |
| `bronze.genoma_etiquetas` | genome-tags.csv | 1.128 | < 0,01 % |

**Total de registros: 41.803.877.** Calificaciones y puntuaciones del genoma concentran el 97,1 % de las filas; las otras cuatro tablas son pequeñas.

## Peso físico en disco

Por tabla (medición del 22 de septiembre; mover tablas de esquema no cambia su tamaño):

| Tabla | Datos | Índices | Total |
|---|---:|---:|---:|
| calificaciones | 1244 MB | 0 bytes | 1245 MB |
| genoma_puntuaciones | 658 MB | 0 bytes | 658 MB |
| etiquetas | 62 MB | 0 bytes | 62 MB |
| peliculas | 4736 kB | 1384 kB | 6160 kB |
| enlaces | 2816 kB | 1384 kB | 4232 kB |
| genoma_etiquetas | 56 kB | 40 kB | 128 kB |

Totales (medición del 4 de octubre): datos 1973 MB, índices 2808 kB, tablas 1976 MB, **base completa 1983 MB (~1,94 GB)**. Las cifras por tabla y los totales provienen de mediciones de fechas distintas y `pg_size_pretty` redondea, por lo que difieren levemente.

## Por qué solo 3 de las 6 tablas tienen índices

`peliculas`, `enlaces` y `genoma_etiquetas` son las únicas con `PRIMARY KEY`, y PostgreSQL crea automáticamente un índice único asociado. Las tres tablas de eventos (`calificaciones`, `etiquetas`, `genoma_puntuaciones`) no tienen PK **por decisión de diseño** (carga cruda sin restricciones; ver [`bronce.md`](bronce.md), D4). Cualquier consulta que filtre por `usuario_id` o `pelicula_id` sobre ellas hace un escaneo secuencial completo. Es esperable en Bronce y se resuelve en Silver con claves e índices.

## Observaciones que estaban pendientes y ya se resolvieron

- **`peliculas` y `enlaces` con 62.423 filas cada una:** confirmado que la relación es 1 a 1 (0 películas sin enlace; `pelicula_id` es PK en ambas).
- **`genoma_puntuaciones` frente al máximo teórico de 70.413.624 (62.423 × 1.128):** el genoma **sí es una matriz densa, pero solo para las películas que cubre**. Hay 13.816 películas en el genoma (22,1 % del catálogo), cada una con exactamente 1.128 filas: 13.816 × 1.128 = **15.584.448**, el conteo real. La aparente contradicción venía de calcular el máximo con todas las películas. La relevancia mínima observada es 0.00025, por lo que **no** hay evidencia de un umbral de corte.

## Estado actual de la carga

`bronze` contiene la carga cruda 1:1 de los 6 CSV, sin transformación. El modelo dimensional (claves sustitutas, dimensión tiempo, hechos y dimensiones) corresponde a la capa Silver, en construcción; ver [`bronce.md`](bronce.md).

## Historial de cambios

- 7 oct 2026: se corrige el total (antes 41.804.777, transposición de dígitos; el correcto es 41.803.877); consultas actualizadas al esquema `bronze`; se resuelven las dos observaciones pendientes; se añaden porcentajes.