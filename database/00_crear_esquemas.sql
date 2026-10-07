/* =====================================================================
   00_crear_esquemas.sql
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallon)
   Ubicacion: database/00_crear_esquemas.sql
   Ejecutar : conectado a la base movielens_db

   La base de datos se crea UNA sola vez, conectado a otra base (p. ej. postgres):
       CREATE DATABASE movielens_db;
   (PostgreSQL no permite CREATE DATABASE IF NOT EXISTS ni dentro de
    una transaccion, por eso no forma parte de este script repetible.)

   Idempotente: se puede ejecutar varias veces sin error ni perdida de datos.
   Convencion del proyecto: todo objeto se referencia con su esquema
   (bronze.tabla, silver.tabla, gold.vista); no se usa search_path.
   ===================================================================== */

BEGIN;

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- La descripcion queda guardada en la BD y se ve en pgAdmin (propiedades del esquema)
COMMENT ON SCHEMA bronze IS
  'Capa Bronce: carga cruda 1:1 de los 6 CSV de MovieLens 25M. Sin transformaciones.';
COMMENT ON SCHEMA silver IS
  'Capa Plata: datos limpios y modelo dimensional en estrella (dimensiones y hechos).';
COMMENT ON SCHEMA gold IS
  'Capa Oro: vistas materializadas agregadas para consumo en Tableau.';

COMMIT;

-- Verificacion: deben aparecer los 3 esquemas con su descripcion
SELECT n.nspname                           AS esquema,
       obj_description(n.oid, 'pg_namespace') AS descripcion
FROM   pg_namespace n
WHERE  n.nspname IN ('bronze', 'silver', 'gold')
ORDER  BY CASE n.nspname WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 ELSE 3 END;
