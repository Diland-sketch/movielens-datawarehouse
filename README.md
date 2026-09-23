# MovieLens 25M — Data Warehouse para Análisis Cinematográfico

Proyecto académico de Data Warehouse construido sobre el dataset público **MovieLens 25M**, publicado por [GroupLens Research](https://grouplens.org/datasets/movielens/25m/) (Universidad de Minnesota).

> ⚠️ Estado del proyecto: fase de comprensión y análisis del dataset. Aún no existe modelo dimensional definitivo, ni arquitectura Medallion (Bronze/Silver/Gold), ni ETLs de transformación. Lo que existe hoy es una carga cruda (Bronze) en PostgreSQL, verificada y documentada.

## Índice de la documentación

| Documento | Contenido |
|---|---|
| [docs/01-entendimiento-dataset.md](docs/01-entendimiento-dataset.md) | Qué es MovieLens 25M, quién lo publica, estructura general y estudio archivo por archivo |
| [docs/volumetria.md](docs/volumetria.md) | Volumetría real verificada por consulta directa: filas, peso en disco, observaciones técnicas |
| [database/schema_bronze.sql](database/schema_bronze.sql) | DDL de las 6 tablas de carga cruda (Bronze) |
| [scripts/cargar_datos.sql](scripts/cargar_datos.sql) | Carga de los 6 CSV a PostgreSQL con `COPY` |
| [scripts/verificacion_volumetria.sql](scripts/verificacion_volumetria.sql) | Consultas de verificación de filas y peso en disco |

## Origen de los datos

- **Dataset:** MovieLens 25M (`ml-25m`)
- **Publicado por:** GroupLens Research, Universidad de Minnesota
- **Descarga oficial:** https://grouplens.org/datasets/movielens/25m/
- **El dataset original NO se sube a este repositorio** (ver `.gitignore`) — la licencia de GroupLens prohíbe su redistribución.

## Licencia y citación del dataset original

> F. Maxwell Harper and Joseph A. Konstan. 2015. *The MovieLens Datasets: History and Context.* ACM Transactions on Interactive Intelligent Systems (TiiS) 5, 4: 19:1–19:19. https://doi.org/10.1145/2827872

## Entorno usado para esta carga

| Recurso | Valor |
|---|---|
| SO | Windows |
| PostgreSQL | 17 |
| Herramienta | pgAdmin 4 (Query Tool) |
| Base de datos | `movielens_db`, encoding UTF8 |

## Estructura del repositorio