-- ============================================================================
-- CAPA GOLD: VISTAS MATERIALIZADAS PARA ANÁLISIS 
-- Proyecto: MovieLens 25M Data Warehouse
-- Autor: Ivan Güette (Ingeniero de Datos)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS gold;

-- 1. VISTA: Ranking y Desempeño de Películas (PEL-01, PEL-02, PEL-03)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.v_pelicula_desempenio AS
SELECT 
    p.pelicula_key,
    p.pelicula_id,
    p.titulo,
    p.anio_estreno,
    p.decada_estreno,
    COUNT(c.calificacion) AS total_valoraciones,
    ROUND(AVG(c.calificacion), 2) AS promedio_calificacion,
    ROUND(STDDEV(c.calificacion), 2) AS desviacion_estandar,
    CASE 
        WHEN COUNT(c.calificacion) >= 1000 THEN 'Alta Densidad (>=1000)'
        WHEN COUNT(c.calificacion) BETWEEN 100 AND 999 THEN 'Media Densidad (100-999)'
        ELSE 'Baja Densidad (<100)'
    END AS segmento_popularidad
FROM silver.dim_pelicula p
JOIN silver.hechos_calificaciones c ON p.pelicula_key = c.pelicula_key
GROUP BY p.pelicula_key, p.pelicula_id, p.titulo, p.anio_estreno, p.decada_estreno;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_pelicula_key ON gold.v_pelicula_desempenio(pelicula_key);


-- 2. VISTA: Comportamiento y Segmentación de Usuarios (USR-01, USR-02, USR-03)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.v_usuario_comportamiento AS
SELECT 
    u.usuario_key,
    u.usuario_id,
    COUNT(c.calificacion) AS total_valoraciones,
    ROUND(AVG(c.calificacion), 2) AS promedio_calificacion,
    COUNT(DISTINCT c.pelicula_key) AS peliculas_distintas_valoradas,
    CASE 
        WHEN COUNT(c.calificacion) >= 500 THEN 'Super Usuario (500+)'
        WHEN COUNT(c.calificacion) BETWEEN 100 AND 499 THEN 'Usuario Frecuente (100-499)'
        ELSE 'Usuario Ocasional (20-99)'
    END AS segmento_actividad
FROM silver.dim_usuario u
JOIN silver.hechos_calificaciones c ON u.usuario_key = c.usuario_key
GROUP BY u.usuario_key, u.usuario_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_usuario_key ON gold.v_usuario_comportamiento(usuario_key);


-- 3. VISTA: Estacionalidad y Tendencias Temporales (TMP-01, TMP-02, TMP-03)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.v_temporalidad_estacionalidad AS
SELECT 
    t.anio,
    t.mes,
    t.nombre_mes,
    t.dia_semana,
    t.nombre_dia,
    t.es_fin_de_semana,
    h.franja AS franja_horaria_utc,
    COUNT(c.calificacion) AS total_valoraciones,
    ROUND(AVG(c.calificacion), 2) AS promedio_calificacion,
    COUNT(CASE WHEN c.calificacion = 5.0 THEN 1 END) AS total_notas_cinco,
    COUNT(CASE WHEN c.calificacion = 0.5 THEN 1 END) AS total_notas_medio
FROM silver.hechos_calificaciones c
JOIN silver.dim_tiempo t ON c.tiempo_key = t.tiempo_key
JOIN silver.dim_hora h ON c.hora_key = h.hora_key
GROUP BY t.anio, t.mes, t.nombre_mes, t.dia_semana, t.nombre_dia, t.es_fin_de_semana, h.franja;