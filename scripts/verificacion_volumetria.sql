-- Conteo de filas por tabla
SELECT 'Calificaciones' AS tabla, COUNT(*) AS total_registros FROM calificaciones
UNION ALL
SELECT 'Genoma Puntuaciones', COUNT(*) FROM genoma_puntuaciones
UNION ALL
SELECT 'Películas', COUNT(*) FROM peliculas
UNION ALL
SELECT 'Etiquetas', COUNT(*) FROM etiquetas
UNION ALL
SELECT 'Enlaces', COUNT(*) FROM enlaces
UNION ALL
SELECT 'Genoma Etiquetas', COUNT(*) FROM genoma_etiquetas;

-- Peso en disco por tabla (datos + índices)
SELECT
    table_name AS tabla,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) AS tamaño_datos,
    pg_size_pretty(pg_indexes_size(quote_ident(table_name))) AS tamaño_indices,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS tamaño_total
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;

-- Peso total de la base de datos
SELECT pg_size_pretty(pg_database_size('movielens_db')) AS tamaño_total_bd;