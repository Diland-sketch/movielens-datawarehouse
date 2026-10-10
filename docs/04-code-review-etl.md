# Informe de Code Review - Pipeline ETL Silver y Constraints
**Revisor:** Ivan Güette (Ingeniero de Datos)  
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
  2. Imposición posterior de Claves Foráneas y creación de Índices B-Tree en las claves foráneas de las tablas de hechos (`idx_calif_pelicula`, `idx_calif_tiempo`, `idx_genoma_pelicula`).

---

## 3. Conclusión
Los scripts fueron corregidos, probados y reejecutados localmente en PostgreSQL 17. La verificación de volumetría fue 100% exitosa con **41.803.877 filas** en Bronce y **25.000.095 filas** en la hechos de calificaciones.