/* =====================================================================
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallion)
   Ubicacion: database/01_tablas_bronze.sql
   Requiere : haber ejecutado 00_crear_esquemas.sql

   Capa Bronce = carga cruda 1:1 de los 6 CSV originales.
   No es el modelo dimensional: sin claves sustitutas, sin dimension
   Tiempo, sin separacion formal de hechos y dimensiones.

   Politica de restricciones (DECISION DEL PROYECTO):
   - SIN FOREIGN KEY: la integridad referencial se valida en el EDA y se
     impone en Silver. Agregarla aqui podria hacer fallar la carga de 25M
     de filas por problemas de calidad aun no conocidos.
   - PRIMARY KEY solo en las 3 tablas de catalogo con clave natural unica
     (peliculas, enlaces, genoma_etiquetas).
   - Tablas de eventos (calificaciones, etiquetas, genoma_puntuaciones)
     sin PK ni indices: carga mas rapida; se indexa en Silver.

   Politica de tipos (DECISION DEL PROYECTO):
   - Tipos fieles al CSV. Un VARCHAR que se desborda da ERROR al cargar
     (falla fuerte), pero un NUMERIC con escala menor redondea EN SILENCIO.
     Por eso 'relevancia' debe verificarse contra el CSV (ver verificacion).
   - fecha_timestamp se conserva como BIGINT (segundos UNIX, UTC);
     la conversion a fecha ocurre en Silver.
   - imdb_id se conserva como texto (VARCHAR).

   Idempotente: CREATE TABLE IF NOT EXISTS. OJO: si la tabla ya existe con
   otra definicion, NO la modifica; por eso se incluye la consulta de
   verificacion de columnas y tipos al final.
   ===================================================================== */

SET client_encoding TO 'UTF8';

BEGIN;

-- 1. Peliculas (movies.csv)
CREATE TABLE IF NOT EXISTS bronze.peliculas (
    pelicula_id INT PRIMARY KEY,
    titulo      VARCHAR(300),
    generos     VARCHAR(200)
);

-- 2. Calificaciones (ratings.csv) - tabla de eventos, 25.000.095 filas
CREATE TABLE IF NOT EXISTS bronze.calificaciones (
    usuario_id      INT,
    pelicula_id     INT,
    calificacion    DECIMAL(3,1),
    fecha_timestamp BIGINT
);

-- 3. Etiquetas de usuarios (tags.csv) - tabla de eventos
CREATE TABLE IF NOT EXISTS bronze.etiquetas (
    usuario_id      INT,
    pelicula_id     INT,
    etiqueta        VARCHAR(255),
    fecha_timestamp BIGINT
);

-- 4. Enlaces externos (links.csv)
CREATE TABLE IF NOT EXISTS bronze.enlaces (
    pelicula_id INT PRIMARY KEY,
    imdb_id     VARCHAR(20),
    tmdb_id     INT
);

-- 5. Diccionario de tags del genoma (genome-tags.csv)
CREATE TABLE IF NOT EXISTS bronze.genoma_etiquetas (
    tag_id   INT PRIMARY KEY,
    etiqueta VARCHAR(255)
);

-- 6. Puntuaciones del genoma (genome-scores.csv) - tabla de eventos
CREATE TABLE IF NOT EXISTS bronze.genoma_puntuaciones (
    pelicula_id INT,
    tag_id      INT,
    relevancia  DECIMAL(6,5)
);

/* ---------------------------------------------------------------------
   DICCIONARIO DE DATOS dentro de la BD (visible en pgAdmin, consultable)
   Fuente de las descripciones: README oficial de ml-25m
   --------------------------------------------------------------------- */
COMMENT ON TABLE bronze.peliculas IS
  'movies.csv. Una fila por pelicula con al menos un rating o un tag.';
COMMENT ON COLUMN bronze.peliculas.pelicula_id IS
  'Id de pelicula en MovieLens (movielens.org/movies/id). Consistente entre ratings, tags, movies y links.';
COMMENT ON COLUMN bronze.peliculas.titulo IS
  'Titulo con el anio de estreno entre parentesis. Puede contener errores o inconsistencias (README).';
COMMENT ON COLUMN bronze.peliculas.generos IS
  'Generos separados por |. Contiene el valor (no genres listed) si no tiene genero.';

COMMENT ON TABLE bronze.calificaciones IS
  'ratings.csv. Una fila = una calificacion de un usuario a una pelicula (evento).';
COMMENT ON COLUMN bronze.calificaciones.usuario_id IS
  'Id anonimizado del usuario. Consistente con tags.csv. Sin datos demograficos.';
COMMENT ON COLUMN bronze.calificaciones.pelicula_id IS
  'Id de la pelicula calificada.';
COMMENT ON COLUMN bronze.calificaciones.calificacion IS
  'Estrellas de 0.5 a 5.0 en incrementos de 0.5.';
COMMENT ON COLUMN bronze.calificaciones.fecha_timestamp IS
  'Segundos desde 1970-01-01 00:00:00 UTC (epoch UNIX).';

COMMENT ON TABLE bronze.etiquetas IS
  'tags.csv. Una fila = un tag aplicado por un usuario a una pelicula (evento).';
COMMENT ON COLUMN bronze.etiquetas.usuario_id IS
  'Id anonimizado del usuario que aplico el tag.';
COMMENT ON COLUMN bronze.etiquetas.pelicula_id IS
  'Id de la pelicula etiquetada.';
COMMENT ON COLUMN bronze.etiquetas.etiqueta IS
  'Texto libre; su significado lo define cada usuario. Sin vocabulario controlado.';
COMMENT ON COLUMN bronze.etiquetas.fecha_timestamp IS
  'Segundos desde 1970-01-01 00:00:00 UTC (epoch UNIX).';

COMMENT ON TABLE bronze.enlaces IS
  'links.csv. Identificadores externos de cada pelicula (IMDb y TMDb).';
COMMENT ON COLUMN bronze.enlaces.pelicula_id IS
  'Id de pelicula en MovieLens.';
COMMENT ON COLUMN bronze.enlaces.imdb_id IS
  'Identificador de la pelicula en IMDb. Se conserva como texto.';
COMMENT ON COLUMN bronze.enlaces.tmdb_id IS
  'Identificador de la pelicula en TMDb. Puede ser NULL.';

COMMENT ON TABLE bronze.genoma_etiquetas IS
  'genome-tags.csv. Diccionario que traduce tag_id del genoma a texto.';
COMMENT ON COLUMN bronze.genoma_etiquetas.tag_id IS
  'Id del tag del genoma. Se genera al exportar el dataset; puede variar entre versiones (README).';
COMMENT ON COLUMN bronze.genoma_etiquetas.etiqueta IS
  'Descripcion del tag del genoma.';

COMMENT ON TABLE bronze.genoma_puntuaciones IS
  'genome-scores.csv. Relevancia de cada tag del genoma para cada pelicula cubierta por el genoma.';
COMMENT ON COLUMN bronze.genoma_puntuaciones.pelicula_id IS
  'Id de la pelicula (solo las cubiertas por el genoma).';
COMMENT ON COLUMN bronze.genoma_puntuaciones.tag_id IS
  'Id del tag del genoma (ver genoma_etiquetas).';
COMMENT ON COLUMN bronze.genoma_puntuaciones.relevancia IS
  'Relevancia del tag para la pelicula. Valores observados entre 0.00025 y 1.0.';

COMMIT;

/* ---------------------------------------------------------------------
   VERIFICACION / DICCIONARIO: columnas, tipos y descripciones en bronze.
   Comparar contra este script; si algun tipo difiere, la BD real y el
   repositorio estan desalineados.
   --------------------------------------------------------------------- */
SELECT c.relname                                   AS tabla,
       a.attnum                                    AS pos,
       a.attname                                   AS columna,
       format_type(a.atttypid, a.atttypmod)        AS tipo,
       col_description(c.oid, a.attnum)            AS descripcion
FROM   pg_class c
JOIN   pg_namespace n ON n.oid = c.relnamespace
JOIN   pg_attribute a ON a.attrelid = c.oid
WHERE  n.nspname = 'bronze'
  AND  c.relkind = 'r'
  AND  a.attnum  > 0
  AND  NOT a.attisdropped
ORDER  BY c.relname, a.attnum;