Proceso ETL: corte vertical de la capa Plata

El ETL se implementa en SQL dentro de PostgreSQL 17 (patrón ELT: los datos ya están en el motor desde Bronce). Cada paso es un script numerado en etl/silver/ y sigue el patrón Extraer, Transformar, Cargar y Validar.

Principios de diseño

Atómico: cada script corre en una transacción. Si la guardia de validación falla, se revierte todo.
Repetible: las dimensiones de clave determinista (dim_tiempo, dim_hora) usan upsert. Las de clave IDENTITY se vacían con TRUNCATE ... RESTART IDENTITY y se recargan en orden, con ORDER BY para que las claves salgan siempre iguales.
Autoverificado: un bloque DO compara conteos y reglas de dominio con lo verificado en Bronce.
Orden: primero dimensiones, al final los hechos, porque los hechos referencian las claves de las dimensiones.
Paso	Tabla destino	Origen	Transformación principal	Filas	Validación
1	dim_tiempo	Generada (generate_series)	Calendario 1995-01-01 a 2019-12-31, tiempo_key YYYYMMDD, día de la semana ISO, nombres en español	9.131	Sin huecos; fechas de control correctas
2	dim_hora	Generada	24 horas con franja UTC de 6 h	24	6 horas por franja
3	dim_usuario	calificaciones UNION etiquetas	usuario_key IDENTITY ordenado por usuario_id	162.541	Claves contiguas 1 a n
4	dim_pelicula	peliculas LEFT JOIN enlaces	Año = último “(YYYY)” del título (regex anclada), título sin ese sufijo, década, tmdb_id nulo conservado	62.423	107 tmdb_id nulos, 412 sin año, años 1874 a 2019
5	hechos_calificaciones	calificaciones + JOIN a dim_usuario y dim_pelicula	Timestamp UNIX a hora UTC, de ahí tiempo_key y hora_key	25.000.095	Total exacto, rango 0.5 a 5.0 en pasos de 0.5, 0 tiempo_key sin dimensión

Decisiones técnicas

Conversión explícita a UTC. La sesión del servidor usa America/Bogota. Sin AT TIME ZONE 'UTC', 5.409.220 calificaciones (21,6 %) caerían en otro día.
Franjas horarias UTC de 6 horas: madrugada 0-5, mañana 6-11, tarde 12-17, noche 18-23. Son franjas UTC, no hora local del usuario, porque el dataset no tiene ubicación.
Anomalía conocida: la película 98063 tiene un paréntesis de más en el título, (1983)), y queda con año nulo, dentro de los 412. No se corrige a mano para no crear reglas para un solo caso.

Resultado preliminar (calificaciones por franja UTC)

Franja	Calificaciones	%
Madrugada	6.253.602	25,0
Mañana	4.174.041	16,7
Tarde	6.168.437	24,7
Noche	8.404.015	33,6

La noche UTC concentra la mayor actividad. Falta cruzarlo con el día de la semana para TMP-03.

Estado: 5 de 11 tablas de Silver cargadas, las que habilitan 13 de los 21 requerimientos. Pendientes: dim_genero con su puente, etiquetas, genoma y la verificación de PK y FK.