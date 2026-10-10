/* =====================================================================
   03_tablas_silver.sql
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallion)
   Ubicacion: database/03_tablas_silver.sql
   Requiere : 00_crear_esquemas.sql
   Origen   : modelo estrella en DBML (aprobado por el equipo el 4 oct 2026)

   Este script es DDL (estructura). NO carga datos: la carga es el ETL
   y vive en etl/silver/.

   DECISIONES DE DISENO (DECISION DEL PROYECTO salvo indicacion):
   1) DIMENSIONES: PK y UNIQUE de la clave natural desde el inicio (son
      pequenas y garantizan unicidad). Las claves sustitutas se generan con
      GENERATED ALWAYS AS IDENTITY; el ETL las asigna ordenando por la clave
      natural para que una recarga produzca las mismas claves.
      Excepciones: tiempo_key (YYYYMMDD) y hora_key (0-23).
   2) HECHOS Y PUENTE: se crean SIN PRIMARY KEY NI FOREIGN KEY. Se agregan
      DESPUES de la carga (etl/silver/09_restricciones_indices.sql).
      Motivo: con FK activas, cargar 25M de filas obliga a PostgreSQL a
      encolar millones de verificaciones y a validarlas fila a fila (lento y
      con alto consumo de memoria). Agregarlas despues valida todo de una
      vez con una sola consulta, y el indice de la PK se construye de golpe.
      El modelo final conserva exactamente las PK y FK del DBML.
   3) AJUSTES FISICOS respecto al DBML (el DBML es modelo logico):
      - varchar sin longitud -> longitudes alineadas con Bronce.
      - numeric sin precision -> NUMERIC(2,1) en calificacion y NUMERIC(6,5)
        en relevancia, con CHECK de dominio (falla fuerte ante datos invalidos).
      - CHECK de coherencia anio_estreno / decada_estreno y de dim_genero.tipo.
      Actualizar el DBML para que refleje estos ajustes.
   4) tmdb_id admite NULL. El tratamiento del nulo (NULL vs -1) se decide en
      el ETL de dim_pelicula; no se impone ningun CHECK hasta cerrar esa decision.

   Idempotente: CREATE TABLE IF NOT EXISTS (no modifica tablas existentes;
   ver la consulta de verificacion final).
   ===================================================================== */

SET client_encoding TO 'UTF8';

BEGIN;

/* ------------------------- DIMENSIONES ------------------------- */

CREATE TABLE IF NOT EXISTS silver.dim_tiempo (
    tiempo_key        INTEGER      PRIMARY KEY,        -- YYYYMMDD, derivada del timestamp en UTC
    fecha             DATE         NOT NULL UNIQUE,
    anio              SMALLINT     NOT NULL,
    trimestre         SMALLINT     NOT NULL,
    mes               SMALLINT     NOT NULL,
    nombre_mes        VARCHAR(12)  NOT NULL,
    dia               SMALLINT     NOT NULL,
    dia_semana        SMALLINT     NOT NULL,           -- ISO: 1 = lunes ... 7 = domingo
    nombre_dia        VARCHAR(12)  NOT NULL,
    es_fin_de_semana  BOOLEAN      NOT NULL
);

CREATE TABLE IF NOT EXISTS silver.dim_hora (
    hora_key  SMALLINT     PRIMARY KEY CHECK (hora_key BETWEEN 0 AND 23),   -- hora UTC
    franja    VARCHAR(10)  NOT NULL                                         -- cortes por definir por el equipo
);

CREATE TABLE IF NOT EXISTS silver.dim_pelicula (
    pelicula_key    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pelicula_id     INTEGER       NOT NULL UNIQUE,     -- clave natural (movieId)
    titulo          VARCHAR(300),                      -- titulo sin el anio
    anio_estreno    SMALLINT,                          -- NULL si el titulo no trae anio
    decada_estreno  SMALLINT,                          -- NULL si no hay anio
    imdb_id         VARCHAR(20),
    tmdb_id         INTEGER,                           -- ver decision 4
    CONSTRAINT ck_pelicula_decada CHECK (
        (anio_estreno IS NULL AND decada_estreno IS NULL)
        OR (anio_estreno IS NOT NULL AND decada_estreno = (anio_estreno / 10) * 10)
    )
);

CREATE TABLE IF NOT EXISTS silver.dim_genero (
    genero_key  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    tipo        VARCHAR(20),                           -- genero | formato (IMAX) | sin_clasificar
    CONSTRAINT ck_genero_tipo CHECK (tipo IN ('genero', 'formato', 'sin_clasificar'))
);

CREATE TABLE IF NOT EXISTS silver.dim_usuario (
    usuario_key  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id   INTEGER NOT NULL UNIQUE               -- sin atributos demograficos en el origen
);

CREATE TABLE IF NOT EXISTS silver.dim_etiqueta (
    etiqueta_key  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    etiqueta      VARCHAR(255) NOT NULL UNIQUE         -- texto normalizado con lower + trim
);

CREATE TABLE IF NOT EXISTS silver.dim_genoma_tag (
    genoma_tag_key  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tag_id          INTEGER NOT NULL UNIQUE,
    etiqueta        VARCHAR(255)
);

/* ----------------- PUENTE Y HECHOS (sin PK/FK: ver decision 2) ----------------- */

-- PK prevista: (pelicula_key, genero_key)
CREATE TABLE IF NOT EXISTS silver.puente_pelicula_genero (
    pelicula_key  INTEGER NOT NULL,
    genero_key    INTEGER NOT NULL
);

-- Grano: una calificacion de un usuario a una pelicula.
-- PK prevista: (usuario_key, pelicula_key)
CREATE TABLE IF NOT EXISTS silver.hechos_calificaciones (
    usuario_key   INTEGER      NOT NULL,
    pelicula_key  INTEGER      NOT NULL,
    tiempo_key    INTEGER      NOT NULL,
    hora_key      SMALLINT     NOT NULL,
    calificacion  NUMERIC(2,1) NOT NULL,
    CONSTRAINT ck_calificacion_dominio CHECK (
        calificacion BETWEEN 0.5 AND 5.0
        AND calificacion * 2 = TRUNC(calificacion * 2)       -- solo pasos de 0.5
    )
);

-- Grano: una aplicacion de un tag por un usuario a una pelicula (hecho sin medidas).
-- PK prevista: (usuario_key, pelicula_key, etiqueta_key); unicidad por verificar.
CREATE TABLE IF NOT EXISTS silver.hechos_etiquetas (
    usuario_key   INTEGER NOT NULL,
    pelicula_key  INTEGER NOT NULL,
    etiqueta_key  INTEGER NOT NULL,
    tiempo_key    INTEGER NOT NULL
);

-- Grano: relevancia de un tag del genoma para una pelicula. Sin dimension de tiempo.
-- PK prevista: (pelicula_key, genoma_tag_key)
CREATE TABLE IF NOT EXISTS silver.hechos_genoma (
    pelicula_key    INTEGER      NOT NULL,
    genoma_tag_key  INTEGER      NOT NULL,
    relevancia      NUMERIC(6,5) NOT NULL,
    CONSTRAINT ck_relevancia_dominio CHECK (relevancia BETWEEN 0 AND 1)
);

/* ------------------- DICCIONARIO (descripcion de cada tabla) ------------------- */
COMMENT ON TABLE silver.dim_tiempo IS 'Dimension. Grano: un dia calendario (UTC). Clave YYYYMMDD.';
COMMENT ON TABLE silver.dim_hora IS 'Dimension. Grano: una hora del dia (0-23, UTC) con su franja.';
COMMENT ON TABLE silver.dim_pelicula IS 'Dimension. Grano: una pelicula. Une movies.csv y links.csv; anio y decada derivados del titulo.';
COMMENT ON TABLE silver.dim_genero IS 'Dimension. Grano: un genero (o formato IMAX, o sin clasificar).';
COMMENT ON TABLE silver.dim_usuario IS 'Dimension minima. Grano: un usuario anonimizado; sin atributos demograficos en el origen.';
COMMENT ON TABLE silver.dim_etiqueta IS 'Dimension. Grano: una etiqueta de usuario normalizada (lower + trim).';
COMMENT ON TABLE silver.dim_genoma_tag IS 'Dimension. Grano: un tag del Tag Genome.';
COMMENT ON TABLE silver.puente_pelicula_genero IS 'Puente muchos a muchos entre peliculas y generos. Una fila por par.';
COMMENT ON TABLE silver.hechos_calificaciones IS 'Hechos. Grano: una calificacion de un usuario a una pelicula. Medida: calificacion.';
COMMENT ON TABLE silver.hechos_etiquetas IS 'Hechos sin medidas. Grano: una aplicacion de una etiqueta por un usuario a una pelicula.';
COMMENT ON TABLE silver.hechos_genoma IS 'Hechos. Grano: relevancia de un tag del genoma para una pelicula. Medida: relevancia.';

/* ------------------------------ GUARDIA ------------------------------ */
DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n
    FROM pg_class c
    WHERE c.relnamespace = 'silver'::regnamespace AND c.relkind = 'r';
    IF n <> 11 THEN
        RAISE EXCEPTION 'Se esperaban 11 tablas en silver y hay %. Se revierte el script.', n;
    END IF;
END $$;

COMMIT;

/* ----------------------------------------------------------------------
   VERIFICACION: columnas y tipos reales en silver (comparar con este script)
   ---------------------------------------------------------------------- */
SELECT c.relname                              AS tabla,
       a.attnum                               AS pos,
       a.attname                              AS columna,
       format_type(a.atttypid, a.atttypmod)   AS tipo,
       CASE WHEN a.attidentity = 'a' THEN 'identity' END AS generada,
       a.attnotnull                           AS not_null
FROM   pg_class c
JOIN   pg_attribute a ON a.attrelid = c.oid
WHERE  c.relnamespace = 'silver'::regnamespace
  AND  c.relkind = 'r'
  AND  a.attnum > 0
  AND  NOT a.attisdropped
ORDER  BY c.relname, a.attnum;