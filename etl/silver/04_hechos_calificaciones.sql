ALTER TABLE silver.hechos_calificaciones
    ALTER COLUMN calificacion TYPE numeric(2,1);

/* =====================================================================
   04_hechos_calificaciones.sql
   Capa: Silver | Tabla: silver.hechos_calificaciones
   Grano: una fila por (usuario, pelicula)
   EXTRACT   : bronze.calificaciones
   TRANSFORM : fecha_timestamp (UNIX) -> hora de reloj UTC; de ahi
               tiempo_key (YYYYMMDD) y hora_key (0-23); claves de usuario
               y pelicula por JOIN a las dimensiones
   LOAD      : INSERT masivo en una sola transaccion
   Requiere  : dim_usuario, dim_pelicula, dim_tiempo y dim_hora cargadas
  ===================================================================== */
BEGIN;

TRUNCATE silver.hechos_calificaciones;

INSERT INTO silver.hechos_calificaciones
    (usuario_key, pelicula_key, tiempo_key, hora_key, calificacion)
SELECT
    u.usuario_key,
    p.pelicula_key,
    to_char(f.ts_utc, 'YYYYMMDD')::int,
    EXTRACT(HOUR FROM f.ts_utc)::smallint,
    c.calificacion
FROM bronze.calificaciones c
JOIN silver.dim_usuario  u ON u.usuario_id  = c.usuario_id
JOIN silver.dim_pelicula p ON p.pelicula_id = c.pelicula_id
CROSS JOIN LATERAL (
    SELECT to_timestamp(c.fecha_timestamp) AT TIME ZONE 'UTC' AS ts_utc
) AS f;

/* ---- GUARDIA ---- */
DO $$
DECLARE
    n BIGINT; n_paso_invalido BIGINT; n_sin_tiempo BIGINT;
    c_min NUMERIC; c_max NUMERIC; f_min INT; f_max INT;
BEGIN
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE calificacion * 2 <> trunc(calificacion * 2)),
           MIN(calificacion), MAX(calificacion),
           MIN(tiempo_key), MAX(tiempo_key)
      INTO n, n_paso_invalido, c_min, c_max, f_min, f_max
      FROM silver.hechos_calificaciones;

    IF n <> 25000095 THEN
        RAISE EXCEPTION 'hechos_calificaciones: % filas (esperadas 25000095)', n;
    END IF;
    IF c_min < 0.5 OR c_max > 5.0 OR n_paso_invalido <> 0 THEN
        RAISE EXCEPTION 'calificacion fuera de dominio: min %, max %, fuera de paso 0.5: %',
                        c_min, c_max, n_paso_invalido;
    END IF;

    SELECT COUNT(*) INTO n_sin_tiempo
      FROM silver.hechos_calificaciones h
      LEFT JOIN silver.dim_tiempo t ON t.tiempo_key = h.tiempo_key
     WHERE t.tiempo_key IS NULL;
    IF n_sin_tiempo <> 0 THEN
        RAISE EXCEPTION 'hechos con tiempo_key inexistente: %', n_sin_tiempo;
    END IF;

    RAISE NOTICE 'hechos_calificaciones: % filas | calificacion % a % | tiempo_key % a %',
                 n, c_min, c_max, f_min, f_max;
END $$;

COMMIT;

ANALYZE silver.hechos_calificaciones;
ANALYZE silver.dim_pelicula;

SELECT COUNT(*) AS cambian_de_dia
FROM bronze.calificaciones
WHERE (to_timestamp(fecha_timestamp) AT TIME ZONE 'UTC')::date
   <> to_timestamp(fecha_timestamp)::date;

SELECT h.franja, COUNT(*) AS calificaciones
FROM silver.hechos_calificaciones f
JOIN silver.dim_hora h ON h.hora_key = f.hora_key
GROUP BY h.franja
ORDER BY MIN(h.hora_key);