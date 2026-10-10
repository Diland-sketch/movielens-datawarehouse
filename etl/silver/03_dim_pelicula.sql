/* =====================================================================
   03_dim_pelicula.sql
   Capa: Silver | Tabla: silver.dim_pelicula
   EXTRACT   : bronze.peliculas LEFT JOIN bronze.enlaces
   TRANSFORM : anio_estreno = ultimo "(YYYY)" del titulo (regex anclada al
               final); titulo sin ese sufijo; decada = anio/10*10;
               tmdb_id nulo se CONSERVA como NULL (decision del proyecto)
   LOAD      : INSERT ordenado por pelicula_id; pelicula_key = IDENTITY
   Atomico, repetible y autoverificado (guardia).
   ===================================================================== */
BEGIN;

TRUNCATE silver.dim_pelicula RESTART IDENTITY;

INSERT INTO silver.dim_pelicula
    (pelicula_id, titulo, anio_estreno, decada_estreno, imdb_id, tmdb_id)
SELECT
    p.pelicula_id,
    t.titulo_limpio,
    t.anio,
    CASE WHEN t.anio IS NULL THEN NULL ELSE (t.anio / 10) * 10 END,
    e.imdb_id,
    e.tmdb_id
FROM bronze.peliculas p
LEFT JOIN bronze.enlaces e ON e.pelicula_id = p.pelicula_id
CROSS JOIN LATERAL (
    SELECT
        NULLIF(btrim(regexp_replace(p.titulo, '\s*\(\d{4}\)\s*$', '')), '') AS titulo_limpio,
        substring(p.titulo FROM '\((\d{4})\)\s*$')::smallint                AS anio
) AS t
ORDER BY p.pelicula_id;

/* ---- GUARDIA ---- */
DO $$
DECLARE
    n INT; k_min INT; k_max INT;
    n_sin_anio INT; n_tmdb_nulo INT; a_min INT; a_max INT;
BEGIN
    SELECT COUNT(*), MIN(pelicula_key), MAX(pelicula_key),
           COUNT(*) FILTER (WHERE anio_estreno IS NULL),
           COUNT(*) FILTER (WHERE tmdb_id IS NULL),
           MIN(anio_estreno), MAX(anio_estreno)
      INTO n, k_min, k_max, n_sin_anio, n_tmdb_nulo, a_min, a_max
      FROM silver.dim_pelicula;

    IF n <> 62423 OR k_min <> 1 OR k_max <> n THEN
        RAISE EXCEPTION 'dim_pelicula inesperada: % filas (esperadas 62423), claves % a %',
                        n, k_min, k_max;
    END IF;
    IF n_tmdb_nulo <> 107 THEN
        RAISE EXCEPTION 'tmdb_id nulos: % (esperados 107)', n_tmdb_nulo;
    END IF;

    RAISE NOTICE 'dim_pelicula: % filas, claves % a %', n, k_min, k_max;
    RAISE NOTICE 'sin anio: % (verificado antes: 412) | anios % a %', n_sin_anio, a_min, a_max;
END $$;

COMMIT;

-- Revision a ojo
SELECT * FROM silver.dim_pelicula WHERE pelicula_id = 1;                       -- Toy Story, 1995, decada 1990
SELECT * FROM silver.dim_pelicula WHERE anio_estreno IS NULL ORDER BY pelicula_id LIMIT 10;
SELECT pelicula_id, titulo, anio_estreno FROM silver.dim_pelicula
WHERE titulo LIKE '%(%)%' ORDER BY pelicula_id LIMIT 10;                       -- titulos alternativos conservados