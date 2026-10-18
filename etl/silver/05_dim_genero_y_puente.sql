BEGIN;
TRUNCATE silver.puente_pelicula_genero, silver.dim_genero RESTART IDENTITY;

-- "(no genres listed)" -> "Sin género"; IMAX se marca como formato
INSERT INTO silver.dim_genero (nombre, tipo)
SELECT g, CASE WHEN g = 'IMAX' THEN 'formato' ELSE 'genero' END
FROM (
  SELECT DISTINCT CASE WHEN u.x = '(no genres listed)' THEN 'Sin género' ELSE u.x END AS g
  FROM bronze.peliculas p
  CROSS JOIN LATERAL unnest(string_to_array(p.generos, '|')) AS u(x)
) s
ORDER BY g;

INSERT INTO silver.puente_pelicula_genero (pelicula_key, genero_key)
SELECT DISTINCT dp.pelicula_key, dg.genero_key
FROM bronze.peliculas p
JOIN silver.dim_pelicula dp ON dp.pelicula_id = p.pelicula_id
CROSS JOIN LATERAL unnest(string_to_array(p.generos, '|')) AS u(x)
JOIN silver.dim_genero dg
  ON dg.nombre = CASE WHEN u.x = '(no genres listed)' THEN 'Sin género' ELSE u.x END;

DO $$
DECLARE g int; pares int; pelis int;
BEGIN
  SELECT count(*) INTO g FROM silver.dim_genero;
  SELECT count(*), count(DISTINCT pelicula_key) INTO pares, pelis FROM silver.puente_pelicula_genero;
  IF g <> 20 THEN RAISE EXCEPTION 'dim_genero: esperado 20, obtenido %', g; END IF;
  IF pelis <> 62423 THEN RAISE EXCEPTION 'puente: películas distintas esperadas 62423, obtenidas %', pelis; END IF;
  IF pares <> 112307 THEN RAISE EXCEPTION 'puente: pares esperados 112307, obtenidos %', pares; END IF;
  RAISE NOTICE 'OK géneros=% pares=% películas=%', g, pares, pelis;
END $$;

COMMIT;