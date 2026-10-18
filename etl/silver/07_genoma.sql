BEGIN;
TRUNCATE silver.hechos_genoma, silver.dim_genoma_tag RESTART IDENTITY;

INSERT INTO silver.dim_genoma_tag (genoma_tag_id, tag)
SELECT tag_id, etiqueta FROM bronze.genoma_etiquetas ORDER BY tag_id;

INSERT INTO silver.hechos_genoma (pelicula_key, genoma_tag_key, relevancia)
SELECT dp.pelicula_key, dt.genoma_tag_key, gs.relevancia
FROM bronze.genoma_puntuaciones gs
JOIN silver.dim_pelicula   dp ON dp.pelicula_id  = gs.pelicula_id
JOIN silver.dim_genoma_tag dt ON dt.genoma_tag_id = gs.tag_id;

DO $$
DECLARE t int; h bigint;
BEGIN
  SELECT count(*) INTO t FROM silver.dim_genoma_tag;
  SELECT count(*) INTO h FROM silver.hechos_genoma;
  IF t <> 1128 THEN RAISE EXCEPTION 'dim_genoma_tag: esperado 1128, obtenido %', t; END IF;
  IF h <> 15584448 THEN RAISE EXCEPTION 'hechos_genoma: esperado 15584448, obtenido %', h; END IF;
  RAISE NOTICE 'OK tags=% hechos=%', t, h;
END $$;

COMMIT;