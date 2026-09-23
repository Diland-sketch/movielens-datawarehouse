-- ============================================================
-- Esquema Bronze — carga cruda de MovieLens 25M
-- ============================================================
-- Refleja 1:1 la estructura de los CSV originales. No es el
-- modelo dimensional del Data Warehouse: sin claves subrogadas,
-- sin dimensión Tiempo, sin separación formal de hechos/dimensiones.
-- Intencionalmente sin FOREIGN KEY: esto es carga cruda, y agregar
-- integridad referencial antes de conocer la calidad real de los
-- datos podría hacer fallar la carga de 25M de filas.
-- ============================================================

-- 1. Películas
CREATE TABLE peliculas (
    pelicula_id INT PRIMARY KEY,
    titulo      VARCHAR(300),
    generos     VARCHAR(200)
);

-- 2. Calificaciones (25.000.095 registros)
CREATE TABLE calificaciones (
    usuario_id      INT,
    pelicula_id     INT,
    calificacion    DECIMAL(3,1),
    fecha_timestamp BIGINT
);

-- 3. Etiquetas de usuarios
CREATE TABLE etiquetas (
    usuario_id      INT,
    pelicula_id     INT,
    etiqueta        VARCHAR(255),
    fecha_timestamp BIGINT
);

-- 4. Enlaces externos (IMDb y TMDb)
CREATE TABLE enlaces (
    pelicula_id INT PRIMARY KEY,
    imdb_id     VARCHAR(20),
    tmdb_id     INT
);

-- 5. Nombres de etiquetas del Genoma
CREATE TABLE genoma_etiquetas (
    tag_id   INT PRIMARY KEY,
    etiqueta VARCHAR(255)
);

-- 6. Puntuaciones del Genoma (15.584.448 registros)
CREATE TABLE genoma_puntuaciones (
    pelicula_id INT,
    tag_id      INT,
    relevancia  DECIMAL(6,5)
);