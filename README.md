# MovieLens 25M — Data Warehouse para Análisis Cinematográfico

Proyecto académico de Data Warehouse construido sobre el dataset público **MovieLens 25M**, publicado por [GroupLens Research](https://grouplens.org/datasets/movielens/25m/) (Universidad de Minnesota).
Equipo 07, Ingeniería de Sistemas, Universidad Popular del Cesar. Curso de Bases de Datos Avanzadas.

> **Estado del proyecto (18 oct 2026):** Arquitectura Medallion implementada sobre PostgreSQL 17.
> Bronce y Plata (11 de 11 tablas) están cargadas y validadas; Oro tiene 12 vistas materializadas
> y el pipeline de exportación a CSV y Google Sheets funciona. Los dashboards de Tableau están en construcción.

## Resumen técnico

| Capa | Contenido | Estado |
|---|---|---|
| Bronce (`bronze`) | 6 tablas, carga 1:1 de los CSV con `COPY`: 41.803.877 filas | Implementada y verificada |
| Plata (`silver`) | Modelo dimensional en constelación: 3 tablas de hechos, 7 dimensiones y 1 tabla puente (11 tablas) con PK y FK | Implementada y validada |
| Oro (`gold`) | 12 vistas materializadas que cubren 20 de los 21 requerimientos analíticos | Implementada (USR-03 pendiente) |
| Exportación | Script Python: 12 CSV y 11 hojas de Google Sheets, solo datos agregados | Implementada y probada |
| BI | Tableau Public: dashboards Panorama, Géneros y Películas/Tags | En construcción |

Dato de rendimiento medido: la misma consulta (valoraciones y promedio por año) tarda 4.435 ms
sobre Plata y 4,4 ms sobre Oro.

## Índice de la documentación

| Documento | Contenido |
|---|---|
| [docs/01-entendimiento-dataset.md](docs/01-entendimiento-dataset.md) | Qué es MovieLens 25M, estructura y estudio archivo por archivo |
| [docs/volumetria.md](docs/volumetria.md) | Volumetría verificada por consulta: filas y peso en disco |
| [docs/bronce.md](docs/bronce.md) | Capa Bronce: esquemas, tablas y carga |
| [docs/02-diagrama-flujo-etl.md](docs/02-diagrama-flujo-etl.md) | Flujo del ETL |
| [docs/etl-silver-corte-vertical.md](docs/etl-silver-corte-vertical.md) | Primer corte vertical de Plata (estado al 10 oct) |
| [docs/04-code-review-etl.md](docs/04-code-review-etl.md) | Revisión de código del ETL |
| [docs/05-silver-gold-exportacion.md](docs/05-silver-gold-exportacion.md) | Plata completa, Oro, exportación, decisiones y validaciones |

## Estructura del repositorio

```
movielens-datawarehouse/
├── database/    DDL: esquemas, tablas Bronce y tablas Plata
│   ├── 00_crear_esquemas.sql
│   ├── 01_tablas_bronze.sql
│   ├── 03_tablas_silver.sql
│   └── 04_ajuste_tablas_silver_pendientes.sql
├── etl/
│   ├── bronze/  02_cargar_bronze.sql (COPY de los 6 CSV)
│   ├── silver/  01 a 07: dimensiones y hechos; 08: PK, FK y ANALYZE
│   ├── gold/    01_vistas_materializadas.sql y 02_vistas_adicionales.sql
│   └── export/  exportar_gold.py, requirements.txt y consultas/ (SQL de agregados)
├── scripts/     verificacion_volumetria.sql
├── docs/        Documentación y decisiones
├── tableau/     Dashboards (los datos exportados NO se versionan)
└── data/        Vacía en el repo: aquí van los CSV originales, ignorados por Git
```

## Origen de los datos

- **Dataset:** MovieLens 25M (`ml-25m`): 25.000.095 calificaciones, 1.093.360 etiquetas y 62.423 películas, de 162.541 usuarios (1995 a 2019).
- **Publicado por:** GroupLens Research, Universidad de Minnesota.
- **Descarga oficial:** https://grouplens.org/datasets/movielens/25m/
- **El dataset original NO se sube a este repositorio** (ver `.gitignore`): la licencia prohíbe su redistribución y su uso comercial.
- **Por la misma razón** los CSV exportados de Oro (`tableau/datos/`) tampoco se versionan. Solo se exportan datos agregados, nunca filas por usuario.

## Cómo reproducir el proyecto

Requisitos: PostgreSQL 17, pgAdmin 4 o `psql`, Python 3.10 o superior y el dataset descargado.

1. Cree la base `movielens_db` (UTF8).
2. Ejecute en orden:
   1. `database/00_crear_esquemas.sql` (esquemas `bronze`, `silver`, `gold`)
   2. `database/01_tablas_bronze.sql`
   3. `etl/bronze/02_cargar_bronze.sql` (ajuste dentro del script la ruta donde descargó los CSV)
   4. `scripts/verificacion_volumetria.sql` (debe dar 41.803.877 filas en total)
   5. `database/03_tablas_silver.sql` y `database/04_ajuste_tablas_silver_pendientes.sql`
   6. `etl/silver/01` a `08`, en orden numérico. El `08` crea PK y FK después de la carga masiva.
   7. `etl/gold/01_vistas_materializadas.sql` y `etl/gold/02_vistas_adicionales.sql`
3. **Exportación:**
```bash
   pip install -r etl/export/requirements.txt
   # PowerShell: $env:PGPASSWORD = "..."   (nunca en el código ni en el repo)
   cd etl/export
   python exportar_gold.py              # solo CSV, en tableau/datos/
   python exportar_gold.py --sheets     # además Google Sheets (cuenta de servicio)
```
   Para Sheets se usan las variables `GOOGLE_APPLICATION_CREDENTIALS` (ruta del JSON de la clave) y `SHEET_ID`.
   El JSON de la clave debe quedar fuera del repositorio.

## Decisiones principales

- Constelación de estrellas (3 hechos que comparten dimensiones): las calificaciones, las etiquetas y la relevancia del genoma tienen granularidades distintas.
- Hora separada del día (`dim_hora`) y todo en UTC: el dataset no tiene ubicación del usuario.
- Géneros con tabla puente (una película puede tener hasta 10): la suma por género supera el total, y está documentado.
- `tmdb_id` nulo se conserva como `NULL` (107 casos) y el año de estreno nulo no se imputa (412 películas).
- Etiquetas normalizadas con `lower` y `trim`: 73.051 textos distintos se reducen a 65.413. Una fila de Bronce colapsa por duplicado tras normalizar (Plata: 1.093.359).
- Oro con medidas aditivas (conteos y sumas): los promedios se recalculan desde las sumas.

## Limitaciones

El dataset registra calificaciones, no visualizaciones. No tiene datos demográficos ni ubicación,
los usuarios son una muestra con al menos 20 calificaciones (sesgo hacia usuarios activos) y el genoma
cubre 13.816 películas (≈ 22,1 %). Todo análisis es conductual.

## Pendiente

- Vista Oro para USR-03 (géneros distintos por usuario).
- Dashboards de Tableau Public y storytelling.
- Documento final en PDF.

## Licencia y citación del dataset original

> F. Maxwell Harper and Joseph A. Konstan. 2015. *The MovieLens Datasets: History and Context.* ACM Transactions on Interactive Intelligent Systems (TiiS) 5, 4: 19:1–19:19. https://doi.org/10.1145/2827872

> Jesse Vig, Shilad Sen, and John Riedl. 2012. *The Tag Genome: Encoding Community Knowledge to Support Novel Interaction.* ACM Trans. Interact. Intell. Syst. 2, 3: 13:1–13:44. https://doi.org/10.1145/2362394.2362395

## Equipo 07

| Integrante | Rol |
|---|---|
| Diland Lopez | Ingeniero de Datos |
| Ivan Güette | Arquitecto de Datos |
| Anghela Gomez | Analista de Datos |

## Entorno usado

| Recurso | Valor |
|---|---|
| SO | Windows |
| PostgreSQL | 17 (base `movielens_db`, UTF8) |
| Herramientas | pgAdmin 4, VS Code, Python 3.13, Git/GitHub, dbdiagram.io |