/* =====================================================================
   02_dim_usuario.sql
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallion)
   Ubicacion: etl/silver/02_dim_usuario.sql
   Requiere : database/03_tablas_silver.sql y bronze cargado
   Carga    : silver.dim_usuario (un usuario anonimizado por fila)

   EXTRACT   : usuario_id de bronze.calificaciones y bronze.etiquetas
   TRANSFORM : UNION (elimina repetidos) + ORDER BY usuario_id
   LOAD      : INSERT; usuario_key lo genera la BD (IDENTITY)

   Por que ORDER BY: asi la clave sustituta se asigna en orden de usuario_id
   y una recarga produce SIEMPRE las mismas claves (reproducible).
   Por que RESTART IDENTITY: TRUNCATE normal no reinicia el contador; sin
   esto, una segunda ejecucion empezaria a numerar donde quedo la anterior.
   Por que UNION de ambas tablas: el usuario es cualquiera que haya
   calificado O etiquetado; no se asume que todo el que etiqueta califica.

   Atomico, repetible y autoverificado (guardia: conteo y claves contiguas).
   ===================================================================== */

BEGIN;

TRUNCATE silver.dim_usuario RESTART IDENTITY;

INSERT INTO silver.dim_usuario (usuario_id)
SELECT usuario_id
FROM (
    SELECT usuario_id FROM bronze.calificaciones
    UNION
    SELECT usuario_id FROM bronze.etiquetas
) AS u
ORDER BY usuario_id;

/* ---- GUARDIA ----
   162.541 = usuarios que declara el README oficial de ml-25m.
   Las claves deben ser contiguas: 1, 2, ..., n */
DO $$
DECLARE
    n INT; k_min INT; k_max INT;
BEGIN
    SELECT COUNT(*), MIN(usuario_key), MAX(usuario_key) INTO n, k_min, k_max FROM silver.dim_usuario;

    IF n <> 162541 OR k_min <> 1 OR k_max <> n THEN
        RAISE EXCEPTION 'dim_usuario inesperada: % filas (esperadas 162541), claves % a %', n, k_min, k_max;
    END IF;
	    IF EXISTS (
        SELECT 1 FROM (
            SELECT usuario_id,
                   LAG(usuario_id) OVER (ORDER BY usuario_key) AS previo
            FROM silver.dim_usuario
        ) t
        WHERE previo >= usuario_id
    ) THEN
        RAISE EXCEPTION 'dim_usuario: usuario_key no sigue el orden de usuario_id';
    END IF;
    RAISE NOTICE 'dim_usuario: % filas, claves % a %', n, k_min, k_max;
END $$;

COMMIT;

-- Vista rapida: las primeras filas deben tener usuario_key = 1, 2, 3... y usuario_id ascendente
SELECT * FROM silver.dim_usuario ORDER BY usuario_key LIMIT 5;

SELECT COUNT(*) AS filas_donde_difieren
FROM silver.dim_usuario
WHERE usuario_key <> usuario_id;