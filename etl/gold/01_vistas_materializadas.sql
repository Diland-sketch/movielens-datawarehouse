-- ============================================================================
-- CAPA GOLD: VISTAS MATERIALIZADAS PARA ANÁLISIS
-- Proyecto: MovieLens 25M Data Warehouse
-- Diseño original: Ivan Güette (Arquitecto de Datos)
-- Revisión y correcciones: Diland Lopez (Ingeniero de Datos)
-- Fuente: esquema silver (corte vertical de calificaciones)
--
-- Convención: cada vista expone medidas ADITIVAS (conteos y sumas). Los
-- promedios se incluyen por comodidad, pero al reagrupar en el BI deben
-- calcularse como SUM(suma_calificaciones) / SUM(total_valoraciones).
-- El script es repetible: se puede ejecutar varias veces (DROP + CREATE).
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS gold;

-- ----------------------------------------------------------------------------
-- 1. Desempeño de películas (PEL-01, PEL-02, PEL-03; PEL-04 se deriva de
--    total_valoraciones). JOIN interno: solo películas con al menos una
--    calificación (las demás no tienen métricas de valoración).
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS gold.v_pelicula_desempenio;

CREATE MATERIALIZED VIEW gold.v_pelicula_desempenio AS
SELECT
    p.pelicula_key,
    p.pelicula_id,
    p.titulo,
    p.anio_estreno,
    p.decada_estreno,
    COUNT(c.calificacion)            AS total_valoraciones,
    SUM(c.calificacion)              AS suma_calificaciones,
    ROUND(AVG(c.calificacion), 2)    AS promedio_calificacion,
    ROUND(STDDEV(c.calificacion), 2) AS desviacion_estandar,  -- NULL si hay 1 sola nota
    CASE
        WHEN COUNT(c.calificacion) >= 1000 THEN 'Alta Densidad (>=1000)'
        WHEN COUNT(c.calificacion) >= 100  THEN 'Media Densidad (100-999)'
        ELSE 'Baja Densidad (<100)'
    END AS segmento_popularidad
FROM silver.dim_pelicula p
JOIN silver.hechos_calificaciones c ON p.pelicula_key = c.pelicula_key
GROUP BY p.pelicula_key, p.pelicula_id, p.titulo, p.anio_estreno, p.decada_estreno;

CREATE UNIQUE INDEX idx_mv_pelicula_key ON gold.v_pelicula_desempenio (pelicula_key);

COMMENT ON MATERIALIZED VIEW gold.v_pelicula_desempenio IS
'Una fila por película calificada. PEL-01 a PEL-03. Los umbrales de segmento_popularidad son una decisión del proyecto. Para rankings filtrar por mínimo de valoraciones: la desviación estándar con pocas notas es poco fiable.';

-- ----------------------------------------------------------------------------
-- 2. Comportamiento de usuarios (USR-01, USR-02). USR-03 (géneros distintos)
--    queda pendiente hasta cargar dim_genero y el puente película-género.
--    No incluye películas distintas: (usuario, película) es único, por lo
--    que coincidiría con total_valoraciones.
--    decil_actividad: 1 = 10% de usuarios más activos (para USR-02).
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS gold.v_usuario_comportamiento;

CREATE MATERIALIZED VIEW gold.v_usuario_comportamiento AS
SELECT
    u.usuario_key,
    u.usuario_id,
    COUNT(c.calificacion)         AS total_valoraciones,
    SUM(c.calificacion)           AS suma_calificaciones,
    ROUND(AVG(c.calificacion), 2) AS promedio_calificacion,
    CASE
        WHEN COUNT(c.calificacion) >= 500 THEN 'Super Usuario (500+)'
        WHEN COUNT(c.calificacion) >= 100 THEN 'Usuario Frecuente (100-499)'
        ELSE 'Usuario Ocasional (20-99)'
    END AS segmento_actividad,
    NTILE(10) OVER (ORDER BY COUNT(c.calificacion) DESC) AS decil_actividad
FROM silver.dim_usuario u
JOIN silver.hechos_calificaciones c ON u.usuario_key = c.usuario_key
GROUP BY u.usuario_key, u.usuario_id;

CREATE UNIQUE INDEX idx_mv_usuario_key ON gold.v_usuario_comportamiento (usuario_key);

COMMENT ON MATERIALIZED VIEW gold.v_usuario_comportamiento IS
'Una fila por usuario. USR-01 y USR-02. Contiene un id de usuario por fila: no exportar a archivos públicos; agregar por segmento o decil. Cada usuario del dataset tiene al menos 20 calificaciones (Readme). Umbrales de segmento: decisión del proyecto.';

-- ----------------------------------------------------------------------------
-- 3. Estacionalidad y tendencias (TMP-01, TMP-02, TMP-03; TMP-04 se calcula
--    con suma_calificaciones / total_valoraciones). Hora en UTC.
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS gold.v_temporalidad_estacionalidad;

CREATE MATERIALIZED VIEW gold.v_temporalidad_estacionalidad AS
SELECT
    t.anio,
    t.mes,
    t.nombre_mes,
    t.dia_semana,
    t.nombre_dia,
    t.es_fin_de_semana,
    h.franja AS franja_horaria_utc,
    COUNT(c.calificacion)                         AS total_valoraciones,
    SUM(c.calificacion)                           AS suma_calificaciones,
    ROUND(AVG(c.calificacion), 2)                 AS promedio_calificacion,
    COUNT(*) FILTER (WHERE c.calificacion = 5.0)  AS total_notas_cinco,
    COUNT(*) FILTER (WHERE c.calificacion = 0.5)  AS total_notas_medio
FROM silver.hechos_calificaciones c
JOIN silver.dim_tiempo t ON c.tiempo_key = t.tiempo_key
JOIN silver.dim_hora   h ON c.hora_key   = h.hora_key
GROUP BY t.anio, t.mes, t.nombre_mes, t.dia_semana, t.nombre_dia,
         t.es_fin_de_semana, h.franja;

CREATE UNIQUE INDEX idx_mv_temporalidad
    ON gold.v_temporalidad_estacionalidad (anio, mes, dia_semana, franja_horaria_utc);

COMMENT ON MATERIALIZED VIEW gold.v_temporalidad_estacionalidad IS
'Calificaciones por año, mes, día de la semana (ISO) y franja horaria UTC. TMP-01 a TMP-04. Las franjas son hora UTC, no la hora local del usuario.';

COMMIT;


SELECT 'pelicula' AS vista, COUNT(*) AS filas, SUM(total_valoraciones) AS total FROM gold.v_pelicula_desempenio
UNION ALL
SELECT 'usuario', COUNT(*), SUM(total_valoraciones) FROM gold.v_usuario_comportamiento
UNION ALL
SELECT 'temporal', COUNT(*), SUM(total_valoraciones) FROM gold.v_temporalidad_estacionalidad;

SELECT percentile_cont(ARRAY[0.25,0.5,0.75,0.9,0.99]) WITHIN GROUP (ORDER BY total_valoraciones) AS p_usuarios
FROM gold.v_usuario_comportamiento;

SELECT percentile_cont(ARRAY[0.25,0.5,0.75,0.9,0.99]) WITHIN GROUP (ORDER BY total_valoraciones) AS p_peliculas
FROM gold.v_pelicula_desempenio;

SELECT segmento_actividad, COUNT(*) AS usuarios,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM gold.v_usuario_comportamiento GROUP BY 1 ORDER BY 2 DESC;

SELECT segmento_popularidad, COUNT(*) AS peliculas,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM gold.v_pelicula_desempenio GROUP BY 1 ORDER BY 2 DESC;