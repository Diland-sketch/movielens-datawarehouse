/* =====================================================================
   02_cargar_bronze.sql
   Proyecto : MovieLens 25M - Data Warehouse (Arquitectura Medallion)
   Requiere : 00_crear_esquemas.sql y 01_tablas_bronze.sql
   Funcion  : carga los 6 CSV originales en bronze.* (Extract + Load)

   ANTES DE EJECUTAR:
   1) Editar 'ruta' (abajo) con la carpeta donde se descomprimio ml-25m,
      terminada en '/'  (en Windows usar barras normales: C:/ml-25m/).
   2) COPY lee el archivo en el SERVIDOR PostgreSQL: el servicio de
      PostgreSQL debe poder leer esa carpeta y el rol debe ser
      superusuario o miembro de pg_read_server_files.

   Propiedades (DECISIONES DEL PROYECTO):
   - ATOMICO: todo el bloque DO es una sola transaccion. Si falla cualquier
     tabla (archivo no encontrado, dato invalido o conteo distinto del
     esperado) se revierte TODO y Bronze queda como estaba.
   - REPETIBLE: cada tabla se vacia (TRUNCATE) antes de cargarse; ejecutarlo
     varias veces nunca duplica filas.
   - AUTOVERIFICADO: compara las filas cargadas con el conteo esperado.
     Los esperados provienen del README oficial (ratings, tags, movies) y de
     las mediciones del proyecto (links, genome-scores, genome-tags).
     Si se usa otra version del dataset hay que actualizarlos a conciencia.

   NOTA: los mensajes de avance (NOTICE) aparecen en la pestana "Messages"
   de pgAdmin o directamente en la consola de psql.
   ===================================================================== */

DO $$
DECLARE
    ruta  text := 'C:/ml-25m/';      -- <<< EDITAR: carpeta del dataset
    r     record;
    n     bigint;
    t0    timestamptz;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            ('peliculas',           'pelicula_id, titulo, generos',                          'movies.csv',        62423),
            ('enlaces',             'pelicula_id, imdb_id, tmdb_id',                         'links.csv',         62423),
            ('genoma_etiquetas',    'tag_id, etiqueta',                                      'genome-tags.csv',   1128),
            ('etiquetas',           'usuario_id, pelicula_id, etiqueta, fecha_timestamp',    'tags.csv',          1093360),
            ('calificaciones',      'usuario_id, pelicula_id, calificacion, fecha_timestamp','ratings.csv',       25000095),
            ('genoma_puntuaciones', 'pelicula_id, tag_id, relevancia',                       'genome-scores.csv', 15584448)
        ) AS v(tabla, columnas, archivo, esperado)
    LOOP
        t0 := clock_timestamp();

        EXECUTE format('TRUNCATE bronze.%I', r.tabla);

        EXECUTE format(
            'COPY bronze.%I (%s) FROM %L WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')',
            r.tabla, r.columnas, ruta || r.archivo);
        GET DIAGNOSTICS n = ROW_COUNT;

        IF n <> r.esperado THEN
            RAISE EXCEPTION 'bronze.%: se cargaron % filas pero se esperaban %. Se revierte toda la carga.',
                            r.tabla, n, r.esperado;
        END IF;

        RAISE NOTICE 'bronze.% <- % : % filas OK (% s)',
                     r.tabla, r.archivo, n,
                     round(extract(epoch FROM clock_timestamp() - t0)::numeric, 1);
    END LOOP;
END $$;

-- Estadisticas para que el planificador haga buenos JOIN en Silver
ANALYZE bronze.peliculas;
ANALYZE bronze.enlaces;
ANALYZE bronze.genoma_etiquetas;
ANALYZE bronze.etiquetas;
ANALYZE bronze.calificaciones;
ANALYZE bronze.genoma_puntuaciones;

-- Resumen final
SELECT 'peliculas' AS tabla, COUNT(*) AS filas FROM bronze.peliculas
UNION ALL SELECT 'enlaces',             COUNT(*) FROM bronze.enlaces
UNION ALL SELECT 'genoma_etiquetas',    COUNT(*) FROM bronze.genoma_etiquetas
UNION ALL SELECT 'etiquetas',           COUNT(*) FROM bronze.etiquetas
UNION ALL SELECT 'calificaciones',      COUNT(*) FROM bronze.calificaciones
UNION ALL SELECT 'genoma_puntuaciones', COUNT(*) FROM bronze.genoma_puntuaciones;