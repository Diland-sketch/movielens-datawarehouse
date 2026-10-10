# ETL capa Plata: corte vertical

**Requisitos:** PostgreSQL 17, esquemas bronze/silver/gold creados, Bronce cargada
(41.803.877 filas) y tablas de Silver creadas (database/03_tablas_silver.sql).

| Orden | Script | Carga | Filas esperadas |
|---|---|---|---|
| 1 | (dim_tiempo) | silver.dim_tiempo | 9.131 |
| 2 | (dim_hora) | silver.dim_hora | 24 |
| 3 | 02_dim_usuario.sql | silver.dim_usuario | 162.541 |
| 4 | 03_dim_pelicula.sql | silver.dim_pelicula | 62.423 |
| 5 | 04_hechos_calificaciones.sql | silver.hechos_calificaciones | 25.000.095 |

Cada script es atómico, repetible y trae su propia guardia de validación.
Las dimensiones se ejecutan siempre antes que los hechos.