# Arquitectura y Diagrama del Flujo ETL / ELT

**Autor:** Ivan Güette (Ingeniero de Datos)
**Entorno:** PostgreSQL 17 | Architecture: Medallion (Bronze -> Silver -> Gold)

---

## 1. Diagrama de Arquitectura del Pipeline

```text
====================================================================================================
CAPA BRONZE (RAW / COPY 1:1)       CAPA SILVER (MODELO DIMENSIONAL)            CAPA GOLD (VISTAS)
====================================================================================================

[ bronze.calificaciones ] ───┬──► [ silver.dim_tiempo ] (9.131 filas)
(25.000.095 filas)           │    └─► EXTRACT(UTC), TO_CHAR(YYYYMMDD)
                             ├──► [ silver.dim_hora ] (24 filas)
                             │    └─► EXTRACT(HOUR UTC), Franja horaria
                             ├──► [ silver.dim_usuario ] (162.541 filas)
                             │    └─► DISTINCT usuario_id (calificaciones + etiquetas)
                             └──► [ silver.hechos_calificaciones ] ───────┬─► [ gold.v_pelicula_desempenio ]
                                  └─► SKs Mapeadas + Calificación        │   [ gold.v_usuario_comportamiento ]
                                                                         │   [ gold.v_temporalidad_estacionalidad ]
[ bronze.peliculas ] ────────┬──► [ silver.dim_pelicula ] (62.423 filas)  │
(62.423 filas)               │    └─► Regex Título, NULL en tmdb_id     │
                             │        y año si no existe                 │
                             └──► [ silver.puente_pelicula_genero ] ──────┤
                                  └─► UNNEST(STRING_TO_ARRAY)            │
                                      (112.307 pares M:N)                │
[ bronze.enlaces ] ──────────┘                                           │
(62.423 filas)                                                           │
                                                                         │
[ bronze.etiquetas ] ────────┬──► [ silver.dim_etiqueta ] (65.413 filas) ┼─► [ Vistas Adicionales Gold ]
(1.093.360 filas)            │    └─► LOWER(), TRIM()                    │
                             └──► [ silver.hechos_etiquetas ] ───────────┤
                                  └─► Factless Fact Table (1.093.359)    │
                                                                         │
[ bronze.genoma_etiquetas ] ─► [ silver.dim_genoma_tag ] (1.128 filas)  │
(1.128 filas)                     └─► Mapeo 1:1                           │
                                                                         │
[ bronze.genoma_puntuaciones ]─► [ silver.hechos_genoma ] ───────────────┴─► [ Exportación a BI ]
(15.584.448 filas)                └─► Puntuaciones de Relevancia              (Python -> Sheets -> Tableau)
====================================================================================================
#### B. Crear el archivo de Code Review:
```bash
cat << 'EOF' > docs/04-code-review-etl.md
# Informe de Code Review - Pipeline ETL Silver y Constraints
**Revisor:** Iván Güette (Ingeniero de Datos)
**Proyecto:** MovieLens 25M Data Warehouse
**Estado:** Aprobado con Observaciones Aplicadas

---

## 1. Resumen de la Revisión

Se realizó el Code Review sobre la suite de scripts de transformación DDL/DML para el poblado del modelo dimensional en la **Capa Plata (Silver)**. La auditoría se enfocó en el rendimiento de ingesta masiva (25M de calificaciones, 15.5M de genoma), integridad referencial y tratamiento de datos atípicos o nulos.

---

## 2. Hallazgos Técnicos y Correcciones Aplicadas

### A. Normalización de Etiquetas y Clave Primaria en `hechos_etiquetas`
* **Observación:** En la Capa Bronce (`bronze.etiquetas`), existen registros donde un mismo usuario asignó la misma etiqueta a la misma película en instantes de tiempo distintos.
* **Impacto:** Un `INSERT` directo causaba violación de la restricción de unicidad (`SQL state: 23505`) sobre la clave primaria compuesta `(usuario_key, pelicula_key, etiqueta_key)`.
* **Solución Implementada:** Se aplicó un agrupamiento explícito (`GROUP BY e.usuario_id, e.pelicula_id, de.etiqueta_key`) seleccionando el primer evento registrado mediante `MIN(tiempo_key)`.

### B. Tratamiento de Valores Nulos Nativo
* **Observación:** La tabla `enlaces` contiene 107 registros donde `tmdb_id` es nulo, y el catálogo de películas contiene 412 títulos que no poseen el formato `(YYYY)` al final del texto.
* **Impacto:** Evitar la imputación forzada con valores centinela (como `-1` o `0`).
* **Solución Implementada:** Se conservaron nativamente como `NULL` en `silver.dim_pelicula`, manteniendo la fidelidad de los datos originales.

### C. Estrategia de Carga y Creación de Claves Foráneas / Índices
* **Observación:** Ejecutar un `INSERT INTO ... SELECT` masivo de 25 millones de filas con Claves Foráneas e Índices B-Tree activos penalizaba severamente el tiempo de ejecución en disco duro I/O.
* **Solución Implementada:** Se desacopló el flujo en dos fases:
  1. Ingesta masiva sin restricciones activas.
  2. Imposición posterior de Claves Foráneas e creación de Índices B-Tree en las claves foráneas de las tablas de hechos (`idx_calif_pelicula`, `idx_calif_tiempo`, `idx_genoma_pelicula`).

---

## 3. Conclusión
Los scripts fueron corregidos, probados y reejecutados localmente en PostgreSQL 17. La verificación de volumetría fue 100% exitosa con **41.803.877 filas** en Bronce y **25.000.095 filas** en la hechos de calificaciones.
