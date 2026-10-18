BEGIN;

DO $$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['dim_genero','puente_pelicula_genero','dim_etiqueta',
                           'dim_genoma_tag','hechos_etiquetas','hechos_genoma'] LOOP
    IF to_regclass('silver.' || t) IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM silver.%I', t) INTO n;
      IF n > 0 THEN
        RAISE EXCEPTION 'silver.% tiene % filas; no se recrea', t, n;
      END IF;
    END IF;
  END LOOP;
END $$;

DROP TABLE IF EXISTS silver.hechos_genoma, silver.hechos_etiquetas,
  silver.puente_pelicula_genero, silver.dim_genoma_tag,
  silver.dim_etiqueta, silver.dim_genero CASCADE;

CREATE TABLE silver.dim_genero (
  genero_key smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre     varchar(30) NOT NULL UNIQUE,
  tipo       varchar(10) NOT NULL CHECK (tipo IN ('genero','formato'))
);

CREATE TABLE silver.puente_pelicula_genero (
  pelicula_key integer  NOT NULL,
  genero_key   smallint NOT NULL
);

CREATE TABLE silver.dim_etiqueta (
  etiqueta_key integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  etiqueta     text    NOT NULL UNIQUE
);

CREATE TABLE silver.dim_genoma_tag (
  genoma_tag_key smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  genoma_tag_id  integer  NOT NULL UNIQUE,
  tag            varchar(100) NOT NULL
);

-- Hechos sin PK/FK: se crean después de la carga masiva (script 08)
CREATE TABLE silver.hechos_etiquetas (
  usuario_key  integer NOT NULL,
  pelicula_key integer NOT NULL,
  etiqueta_key integer NOT NULL,
  tiempo_key   integer NOT NULL
);

CREATE TABLE silver.hechos_genoma (
  pelicula_key   integer      NOT NULL,
  genoma_tag_key smallint     NOT NULL,
  relevancia     numeric(6,5) NOT NULL
);

COMMIT;