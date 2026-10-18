BEGIN;
TRUNCATE silver.hechos_etiquetas, silver.dim_etiqueta RESTART IDENTITY;

INSERT INTO silver.dim_etiqueta (etiqueta)
SELECT DISTINCT lower(trim(etiqueta)) FROM bronze.etiquetas ORDER BY 1;

-- Timestamp UNIX -> fecha UTC (la sesión está en America/Bogota, por eso AT TIME ZONE 'UTC')
-- DISTINCT ON: si la normalización une dos etiquetas del mismo usuario/película, se conserva la más antigua
INSERT INTO silver.hechos_etiquetas (usuario_key, pelicula_key, etiqueta_key, tiempo_key)
SELECT DISTINCT ON (du.usuario_key, dp.pelicula_key, de.etiqueta_key)
       du.usuario_key, dp.pelicula_key, de.etiqueta_key,
       to_char(to_timestamp(e.fecha_timestamp) AT TIME ZONE 'UTC', 'YYYYMMDD')::integer
FROM bronze.etiquetas e
JOIN silver.dim_usuario  du ON du.usuario_id  = e.usuario_id
JOIN silver.dim_pelicula dp ON dp.pelicula_id = e.pelicula_id
JOIN silver.dim_etiqueta de ON de.etiqueta    = lower(trim(e.etiqueta))
ORDER BY du.usuario_key, dp.pelicula_key, de.etiqueta_key, e.fecha_timestamp;

DO $$
DECLARE d int; h int;
BEGIN
  SELECT count(*) INTO d FROM silver.dim_etiqueta;
  SELECT count(*) INTO h FROM silver.hechos_etiquetas;
  IF d <> 65413 THEN RAISE EXCEPTION 'dim_etiqueta: esperado 65413, obtenido %', d; END IF;
  IF h > 1093360 OR h = 0 THEN RAISE EXCEPTION 'hechos_etiquetas fuera de rango: %', h; END IF;
  RAISE NOTICE 'OK etiquetas=% hechos=% (filas colapsadas por normalización: %)', d, h, 1093360 - h;
END $$;

COMMIT;