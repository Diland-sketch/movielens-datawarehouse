# 01 — Entendimiento del dataset MovieLens 25M

Convenciones: **DATO CONFIRMADO** (README oficial o consulta real) · **DECISIÓN DEL PROYECTO** · **PROPUESTA** (a validar) · **SUPOSICIÓN/PENDIENTE** (no comprobado).

Estructura de las tablas, tipos y diccionario completo: ver [`bronce.md`](bronce.md). Conteos y peso en disco: ver [`volumetria.md`](volumetria.md).

## 1. Visión general

**DATO CONFIRMADO (README):**
- MovieLens es un servicio de recomendación de películas, publicado por **GroupLens Research** (Departamento de Ciencias de la Computación e Ingeniería, Universidad de Minnesota, activo desde 1992).
- ml-25m contiene actividad real: 25.000.095 ratings y 1.093.360 tags sobre 62.423 películas, de 162.541 usuarios, entre el 9 de enero de 1995 y el 21 de noviembre de 2019.
- Los usuarios se seleccionaron al azar y **todos habían calificado al menos 20 películas**.
- **No incluye datos demográficos**: cada usuario es solo un id anonimizado.
- Solo incluye películas con al menos un rating o un tag; no es un catálogo completo de cine.
- Los ids de película son consistentes entre ratings, tags, movies y links; los ids de usuario, entre ratings y tags.
- Uso permitido para investigación, con obligación de citar a Harper & Konstan (2015); sin redistribución ni uso comercial sin permiso.

## 2. Estudio archivo por archivo

### 2.1 `calificaciones` (ratings.csv)

- **Propósito:** registra cada calificación que un usuario dio a una película.
- **Granularidad:** una fila = un evento de calificación (usuario, película, momento).
- **Columnas:** `usuario_id`, `pelicula_id`, `calificacion` (0.5 a 5.0 en pasos de 0.5), `fecha_timestamp` (segundos UNIX en UTC).
- **Volumen:** 25.000.095 filas.
- **Verificado (DATO CONFIRMADO, mediciones del proyecto):** 0 duplicados en (usuario, película); 0 películas huérfanas respecto a `peliculas`; 0 nulos; fechas entre 1995-01-09 y 2019-11-21.
- **Pendiente:** confirmar que `calificacion` toma exactamente 10 valores distintos entre 0.5 y 5.0; confirmar el mínimo de calificaciones por usuario (el README dice 20).
- **Rol en el modelo (DECISIÓN DEL PROYECTO):** `hechos_calificaciones`; la métrica es `calificacion`; el timestamp se descompone en `dim_tiempo` y `dim_hora`.

### 2.2 `peliculas` (movies.csv)

- **Propósito:** catálogo de películas.
- **Granularidad:** una fila = una película.
- **Columnas:** `pelicula_id` (PK), `titulo` (con el año de estreno entre paréntesis), `generos` (lista separada por `|`).
- **Volumen:** 62.423 filas.
- **Verificado:**
  - 412 títulos sin año de estreno reconocible.
  - 5.062 películas sin género (`(no genres listed)`).
  - 19 géneros distintos más ese valor; entre ellos aparece IMAX, que el README no lista.
  - El género se escribe `Children`, no `Children's` como indica el README.
- **Pendiente:** definir la regla exacta de extracción del año (último `(YYYY)` al final del título) y comprobar el rango de años obtenido.
- **Rol en el modelo:** `dim_pelicula` (con `anio_estreno` y `decada_estreno` derivados del título), `dim_genero` y `puente_pelicula_genero` (relación muchos a muchos).

### 2.3 `etiquetas` (tags.csv)

- **Propósito:** tags de texto libre que los usuarios aplican a películas.
- **Granularidad:** una fila = un tag aplicado por un usuario a una película.
- **Columnas:** `usuario_id`, `pelicula_id`, `etiqueta`, `fecha_timestamp`.
- **Volumen:** 1.093.360 filas.
- **Verificado:** 0 duplicados en (usuario, película, etiqueta); 0 huérfanos; 73.051 etiquetas distintas, que bajan a 65.413 al aplicar minúsculas y quitar espacios en los extremos.
- **Pendiente:** comprobar si normalizar genera colisiones en la clave (usuario, película, etiqueta normalizada); rango real de `fecha_timestamp`.
- **Rol en el modelo:** `dim_etiqueta` y `hechos_etiquetas`. **PROPUESTA** abierta: normalizar la etiqueta en Silver y conservar el texto original en Bronce.

### 2.4 `enlaces` (links.csv)

- **Propósito:** identificadores externos de cada película (IMDb y TMDb).
- **Granularidad:** una fila = una película.
- **Columnas:** `pelicula_id` (PK), `imdb_id`, `tmdb_id`.
- **Volumen:** 62.423 filas, relación 1 a 1 con `peliculas` (0 películas sin enlace).
- **Verificado:** 107 nulos, todos en `tmdb_id`; es la única columna con nulos en todo el dataset.
- **Pendiente:** formato de `imdb_id` (ceros a la izquierda). **PROPUESTA** abierta: conservar `NULL` en `tmdb_id` en Silver en lugar de imputar `-1`.
- **Rol en el modelo:** atributos `imdb_id` y `tmdb_id` de `dim_pelicula`.

### 2.5 `genoma_puntuaciones` (genome-scores.csv)

- **Propósito:** relevancia de cada tag del genoma para cada película cubierta.
- **Granularidad:** una fila = un par (película, tag del genoma).
- **Columnas:** `pelicula_id`, `tag_id`, `relevancia`.
- **Volumen:** 15.584.448 filas.
- **Verificado:** el genoma cubre 13.816 películas (22,1 % del catálogo), cada una con exactamente 1.128 tags: 13.816 × 1.128 = 15.584.448. Por tanto es una matriz densa **para las películas que cubre**; el máximo teórico de 70.413.624 se obtenía con las 62.423 películas. Relevancia entre 0.00025 y 1.0; 0 duplicados en (película, tag).
- **Pendiente:** comprobar contra el CSV que ninguna relevancia tenga más de 5 decimales (ver `bronce.md`, sección 8).
- **Rol en el modelo:** `hechos_genoma`; la métrica es `relevancia`.

### 2.6 `genoma_etiquetas` (genome-tags.csv)

- **Propósito:** diccionario que traduce `tag_id` a texto.
- **Granularidad:** una fila = un tag del genoma.
- **Columnas:** `tag_id` (PK), `etiqueta`.
- **Volumen:** 1.128 filas.
- **Nota (README):** los `tag_id` se generan al exportar el dataset y pueden variar entre versiones.
- **Rol en el modelo:** `dim_genoma_tag`.

### 2.7 Usuarios (no existe archivo)

No hay un `users.csv`: el usuario solo existe como `usuario_id` dentro de ratings y tags. **DECISIÓN DEL PROYECTO:** `dim_usuario` mínima, derivada de los ids distintos de `calificaciones` y `etiquetas`; los segmentos (por frecuencia, promedio) se calculan en Gold, no se almacenan en la dimensión.

## 3. Limitaciones del dataset

**DATO CONFIRMADO (README):**
- Sin demografía: no se puede analizar por edad, género ni ubicación; todo el análisis es de comportamiento observable.
- Selección aleatoria de usuarios con al menos 20 ratings: el dataset no refleja usuarios ocasionales, lo que condiciona la segmentación por frecuencia (USR-01).
- Solo películas con al menos un rating o un tag.
- Los títulos pueden contener errores o inconsistencias.
- Los tags son texto libre sin vocabulario controlado.
- Los timestamps están en UTC; no hay zona horaria del usuario.
- El genoma cubre solo 13.816 de las 62.423 películas.

## 4. Preguntas abiertas

1. Valores distintos de `calificacion` (esperado: 10).
2. Mínimo de calificaciones por usuario (README: 20).
3. Rango de fechas de `etiquetas` frente al calendario de `dim_tiempo`.
4. Colisiones al normalizar etiquetas.
5. Formato de `imdb_id`.
6. Decisión sobre `tmdb_id` nulo (`NULL` frente a `-1`).
7. Fidelidad de `relevancia` frente al CSV.