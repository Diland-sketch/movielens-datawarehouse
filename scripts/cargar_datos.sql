-- Ajustar la ruta 'C:/ml-25m/' a donde cada quien descomprimió el dataset
-- Ejecutado con COPY (lado servidor) desde el Query Tool de pgAdmin

COPY peliculas(pelicula_id, titulo, generos)
FROM 'C:/ml-25m/movies.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY enlaces(pelicula_id, imdb_id, tmdb_id)
FROM 'C:/ml-25m/links.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY genoma_etiquetas(tag_id, etiqueta)
FROM 'C:/ml-25m/genome-tags.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY etiquetas(usuario_id, pelicula_id, etiqueta, fecha_timestamp)
FROM 'C:/ml-25m/tags.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY calificaciones(usuario_id, pelicula_id, calificacion, fecha_timestamp)
FROM 'C:/ml-25m/ratings.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY genoma_puntuaciones(pelicula_id, tag_id, relevancia)
FROM 'C:/ml-25m/genome-scores.csv'
DELIMITER ',' CSV HEADER ENCODING 'UTF8';