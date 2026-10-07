/* =====================================================================
   verificacion_volumetria.sql  
   Ejecutar conectado a movielens_db. Solo lectura.
   Verifica la capa Bronce: conteos contra lo esperado, peso en disco.
   Esperados: README oficial (ratings, tags, movies) y mediciones del proyecto.
   ===================================================================== */

-- 1. Conteo por tabla contra el esperado (la columna 'coincide' debe ser true en todas)
WITH c AS (
    SELECT 'calificaciones' AS tabla, COUNT(*) AS filas FROM bronze.calificaciones
    UNION ALL SELECT 'genoma_puntuaciones', COUNT(*) FROM bronze.genoma_puntuaciones
    UNION ALL SELECT 'etiquetas',           COUNT(*) FROM bronze.etiquetas
    UNION ALL SELECT 'peliculas',           COUNT(*) FROM bronze.peliculas
    UNION ALL SELECT 'enlaces',             COUNT(*) FROM bronze.enlaces
    UNION ALL SELECT 'genoma_etiquetas',    COUNT(*) FROM bronze.genoma_etiquetas
),
e (tabla, esperado) AS (
    VALUES ('calificaciones',      25000095),
           ('genoma_puntuaciones', 15584448),
           ('etiquetas',            1093360),
           ('peliculas',              62423),
           ('enlaces',                62423),
           ('genoma_etiquetas',        1128)
),
r AS (
    SELECT c.tabla, c.filas, e.esperado FROM c JOIN e USING (tabla)
)
SELECT * FROM (
    SELECT tabla, filas, esperado, (filas = esperado) AS coincide FROM r
    UNION ALL
    SELECT 'TOTAL', SUM(filas), SUM(esperado), (SUM(filas) = SUM(esperado)) FROM r
) x
ORDER BY (tabla = 'TOTAL'), esperado DESC;

-- 2. Peso en disco por tabla del esquema bronze (datos + indices)
SELECT c.relname                                       AS tabla,
       pg_size_pretty(pg_relation_size(c.oid))         AS tamano_datos,
       pg_size_pretty(pg_indexes_size(c.oid))          AS tamano_indices,
       pg_size_pretty(pg_total_relation_size(c.oid))   AS tamano_total
FROM   pg_class c
WHERE  c.relnamespace = 'bronze'::regnamespace
  AND  c.relkind = 'r'
ORDER  BY pg_total_relation_size(c.oid) DESC;

-- 3. Peso total de la base de datos
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_total_bd;