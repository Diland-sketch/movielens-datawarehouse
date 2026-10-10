/* =====================================================================
   01_dim_tiempo_hora.sql
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallion)
   Ubicacion: etl/silver/01_dim_tiempo_hora.sql
   Requiere : database/03_tablas_silver.sql
   Carga    : silver.dim_tiempo (9.131 dias) y silver.dim_hora (24 horas)

   Tipo de carga: GENERADA (no lee Bronce). Es una dimension de calendario.
   Todo en UTC, igual que los timestamps del dataset.

   Propiedades: atomico (una transaccion), repetible (TRUNCATE previo) y
   autoverificado (guardia de conteos; si falla, ROLLBACK de todo).
   Guardar este archivo en UTF-8 (los nombres de mes, dia y franja llevan tilde).
   ===================================================================== */

SET client_encoding TO 'UTF8';
SET TIME ZONE 'UTC';

BEGIN;

/* ---- dim_tiempo: 1 fila = 1 dia, de 1995-01-01 a 2019-12-31 ----
   Los ratings van de 1995-01-09 a 2019-11-21; se cubre el anio completo.
   25 anios * 365 dias + 6 bisiestos (1996, 2000, 2004, 2008, 2012, 2016) = 9131 */
TRUNCATE silver.dim_tiempo;

INSERT INTO silver.dim_tiempo
    (tiempo_key, fecha, anio, trimestre, mes, nombre_mes,
     dia, dia_semana, nombre_dia, es_fin_de_semana)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR    FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH   FROM d)::SMALLINT,
    (ARRAY['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio',
           'Agosto','Septiembre','Octubre','Noviembre','Diciembre'])
        [EXTRACT(MONTH FROM d)::INT],
    EXTRACT(DAY     FROM d)::SMALLINT,
    EXTRACT(ISODOW  FROM d)::SMALLINT,
    (ARRAY['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])
        [EXTRACT(ISODOW FROM d)::INT],
    EXTRACT(ISODOW  FROM d) IN (6, 7)
FROM generate_series('1995-01-01'::TIMESTAMP,
                     '2019-12-31'::TIMESTAMP,
                     INTERVAL '1 day') AS g(d);

/* ---- dim_hora: 1 fila = 1 hora UTC ----
   Cortes de franja = PROPUESTA pendiente de aprobacion del equipo:
   Madrugada 0-5, Mañana 6-11, Tarde 12-17, Noche 18-23 */
TRUNCATE silver.dim_hora;

INSERT INTO silver.dim_hora (hora_key, franja)
SELECT
    h::SMALLINT,
    CASE
        WHEN h BETWEEN 0  AND 5  THEN 'Madrugada'
        WHEN h BETWEEN 6  AND 11 THEN 'Mañana'
        WHEN h BETWEEN 12 AND 17 THEN 'Tarde'
        ELSE                          'Noche'
    END
FROM generate_series(0, 23) AS g(h);

/* ---- GUARDIA: conteos y rango esperados; si no, se revierte todo ---- */
DO $$
DECLARE
    n_tiempo INT; n_hora INT; f_min DATE; f_max DATE;
BEGIN
    SELECT COUNT(*), MIN(fecha), MAX(fecha) INTO n_tiempo, f_min, f_max FROM silver.dim_tiempo;
    SELECT COUNT(*) INTO n_hora FROM silver.dim_hora;

    IF n_tiempo <> 9131 OR n_hora <> 24
       OR f_min <> DATE '1995-01-01' OR f_max <> DATE '2019-12-31' THEN
        RAISE EXCEPTION 'Resultado inesperado: dim_tiempo=% (esperado 9131, % a %), dim_hora=% (esperado 24)',
                        n_tiempo, f_min, f_max, n_hora;
    END IF;
    RAISE NOTICE 'dim_tiempo: % filas (% a %) | dim_hora: % filas', n_tiempo, f_min, f_max, n_hora;
END $$;

COMMIT;

-- ---------- VALIDACIONES ----------
-- 1) Filas esperadas: 9131 (25 años x 365 + 6 bisiestos)
-- 2) Sin huecos: total = (max - min + 1)
SELECT
    COUNT(*)                           AS total_filas,
    MIN(fecha)                         AS fecha_min,
    MAX(fecha)                         AS fecha_max,
    MAX(fecha) - MIN(fecha) + 1        AS dias_esperados,
    COUNT(DISTINCT tiempo_key)         AS claves_distintas
FROM silver.dim_tiempo;

-- ---------- VALIDACIONES ----------
-- Esperado: 24 filas en total y 6 por cada franja
SELECT franja, COUNT(*) AS horas, MIN(hora_key) AS desde, MAX(hora_key) AS hasta
FROM silver.dim_hora
GROUP BY franja
ORDER BY desde;

-- Vista rapida para revisar a ojo (debe mostrar tildes correctas)
SELECT * FROM silver.dim_tiempo WHERE fecha IN ('1995-01-09', '2000-02-29', '2019-11-21');
SELECT * FROM silver.dim_hora ORDER BY hora_key;