-- Orden inverso por dependencia
DROP MATERIALIZED VIEW IF EXISTS gold.v_genero_resumen;
DROP MATERIALIZED VIEW IF EXISTS gold.v_genero_anio;
DROP MATERIALIZED VIEW IF EXISTS gold.v_genero_decada;
DROP MATERIALIZED VIEW IF EXISTS gold.v_rating_distribucion;
DROP MATERIALIZED VIEW IF EXISTS gold.v_rating_resumen_anual;
DROP MATERIALIZED VIEW IF EXISTS gold.v_tags_top;
DROP MATERIALIZED VIEW IF EXISTS gold.v_tags_cobertura;
DROP MATERIALIZED VIEW IF EXISTS gold.v_genoma_genero;
DROP MATERIALIZED VIEW IF EXISTS gold.v_genoma_correlacion;

-- RAT-01 / RAT-03: distribución por año y valor; tipo_valor separa enteras de medias estrellas
CREATE MATERIALIZED VIEW gold.v_rating_distribucion AS
SELECT t.anio,
       f.calificacion,
       CASE WHEN f.calificacion = floor(f.calificacion) THEN 'Entera' ELSE 'Media estrella' END AS tipo_valor,
       COUNT(*) AS n_valoraciones
FROM silver.hechos_calificaciones f
JOIN silver.dim_tiempo t ON t.tiempo_key = f.tiempo_key
GROUP BY 1, 2, 3;

-- RAT-02: % >= 4.0 y media vs mediana, por año y total (periodo = 'Total')
CREATE MATERIALIZED VIEW gold.v_rating_resumen_anual AS
SELECT COALESCE(t.anio::text, 'Total') AS periodo,
       COUNT(*)                         AS n_valoraciones,
       SUM(f.calificacion)              AS suma_calificaciones,
       COUNT(*) FILTER (WHERE f.calificacion >= 4.0) AS n_mayor_igual_4,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY f.calificacion::double precision) AS mediana
FROM silver.hechos_calificaciones f
JOIN silver.dim_tiempo t ON t.tiempo_key = f.tiempo_key
GROUP BY GROUPING SETS ((t.anio), ());

-- GEN-01: género x año de valoración (una película cuenta en cada uno de sus géneros)
CREATE MATERIALIZED VIEW gold.v_genero_anio AS
WITH peli_anio AS (
  SELECT f.pelicula_key, t.anio,
         COUNT(*) AS n,
         SUM(f.calificacion) AS s,
         SUM(f.calificacion * f.calificacion) AS s2
  FROM silver.hechos_calificaciones f
  JOIN silver.dim_tiempo t ON t.tiempo_key = f.tiempo_key
  GROUP BY f.pelicula_key, t.anio
)
SELECT g.nombre AS genero, g.tipo, p.anio AS anio_valoracion,
       SUM(p.n)::bigint AS n_valoraciones,
       SUM(p.s)         AS suma_calificaciones,
       SUM(p.s2)        AS suma_cuadrados
FROM peli_anio p
JOIN silver.puente_pelicula_genero b ON b.pelicula_key = p.pelicula_key
JOIN silver.dim_genero g             ON g.genero_key   = b.genero_key
GROUP BY g.nombre, g.tipo, p.anio;

-- GEN-02: promedio y polarización (desviación estándar poblacional) por género
CREATE MATERIALIZED VIEW gold.v_genero_resumen AS
SELECT genero, tipo,
       SUM(n_valoraciones)::bigint AS n_valoraciones,
       ROUND(SUM(suma_calificaciones) / SUM(n_valoraciones), 3) AS promedio,
       ROUND(sqrt(GREATEST(
         SUM(suma_cuadrados) / SUM(n_valoraciones)
         - power(SUM(suma_calificaciones) / SUM(n_valoraciones), 2), 0)), 3) AS desv_estandar
FROM gold.v_genero_anio
GROUP BY genero, tipo;

-- GEN-03: década de estreno x género ('Sin año' para las 412 sin año)
CREATE MATERIALIZED VIEW gold.v_genero_decada AS
WITH peli AS (
  SELECT pelicula_key, COUNT(*) AS n, SUM(calificacion) AS s
  FROM silver.hechos_calificaciones
  GROUP BY pelicula_key
)
SELECT COALESCE(dp.decada_estreno::text, 'Sin año') AS decada_estreno,
       g.nombre AS genero, g.tipo,
       SUM(p.n)::bigint AS n_valoraciones,
       SUM(p.s)         AS suma_calificaciones,
       COUNT(*)         AS n_peliculas_valoradas
FROM peli p
JOIN silver.dim_pelicula dp          ON dp.pelicula_key = p.pelicula_key
JOIN silver.puente_pelicula_genero b ON b.pelicula_key  = p.pelicula_key
JOIN silver.dim_genero g             ON g.genero_key    = b.genero_key
GROUP BY 1, 2, 3;

-- TAG-01: tags más usados (etiquetas normalizadas)
CREATE MATERIALIZED VIEW gold.v_tags_top AS
SELECT de.etiqueta,
       COUNT(*)                     AS n_aplicaciones,
       COUNT(DISTINCT h.pelicula_key) AS n_peliculas,
       COUNT(DISTINCT h.usuario_key)  AS n_usuarios
FROM silver.hechos_etiquetas h
JOIN silver.dim_etiqueta de ON de.etiqueta_key = h.etiqueta_key
GROUP BY de.etiqueta;

-- TAG-02: cobertura real del etiquetado
CREATE MATERIALIZED VIEW gold.v_tags_cobertura AS
SELECT 'Películas' AS entidad,
       (SELECT COUNT(*) FROM silver.dim_pelicula) AS total,
       (SELECT COUNT(DISTINCT pelicula_key) FROM silver.hechos_etiquetas) AS con_tag
UNION ALL
SELECT 'Usuarios',
       (SELECT COUNT(*) FROM silver.dim_usuario),
       (SELECT COUNT(DISTINCT usuario_key) FROM silver.hechos_etiquetas);

-- TAG-03: relevancia promedio de cada tag del genoma por género (ranking 1 = más característico)
CREATE MATERIALIZED VIEW gold.v_genoma_genero AS
SELECT genero, tipo, tag, relevancia_promedio, n_peliculas,
       ROW_NUMBER() OVER (PARTITION BY genero ORDER BY relevancia_promedio DESC) AS ranking_en_genero
FROM (
  SELECT g.nombre AS genero, g.tipo, gt.tag,
         ROUND(AVG(hg.relevancia), 4) AS relevancia_promedio,
         COUNT(*) AS n_peliculas
  FROM silver.hechos_genoma hg
  JOIN silver.puente_pelicula_genero b ON b.pelicula_key  = hg.pelicula_key
  JOIN silver.dim_genero g             ON g.genero_key    = b.genero_key
  JOIN silver.dim_genoma_tag gt        ON gt.genoma_tag_key = hg.genoma_tag_key
  GROUP BY g.nombre, g.tipo, gt.tag
) x;

-- TAG-04: correlación de Pearson entre relevancia del tag y calificación promedio de la película
-- DECISIÓN a confirmar: umbral de 100 valoraciones por película (el mismo del ranking PEL-02)
CREATE MATERIALIZED VIEW gold.v_genoma_correlacion AS
WITH prom AS (
  SELECT pelicula_key, AVG(calificacion)::double precision AS promedio
  FROM silver.hechos_calificaciones
  GROUP BY pelicula_key
  HAVING COUNT(*) >= 100
)
SELECT gt.tag,
       COUNT(*) AS n_peliculas,
       ROUND(corr(hg.relevancia::double precision, p.promedio)::numeric, 4) AS correlacion
FROM silver.hechos_genoma hg
JOIN prom p                   ON p.pelicula_key = hg.pelicula_key
JOIN silver.dim_genoma_tag gt ON gt.genoma_tag_key = hg.genoma_tag_key
GROUP BY gt.tag;

COMMENT ON MATERIALIZED VIEW gold.v_genero_anio IS
  'Una película cuenta en cada uno de sus géneros: la suma por género supera el total (diseño con tabla puente).';

   SELECT entidad, total, con_tag FROM gold.v_tags_cobertura;         -- 62423/45251 y 162541/14592
   SELECT SUM(n_valoraciones) FROM gold.v_rating_distribucion;        -- 25000095
   SELECT * FROM gold.v_rating_resumen_anual WHERE periodo = 'Total'; -- n_valoraciones = 25000095
   SELECT COUNT(*) FROM gold.v_genoma_correlacion;                    -- 1128