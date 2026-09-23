# 01 — Entendimiento del dataset MovieLens 25M

Convenciones: **DATO CONFIRMADO** (verificado en el README oficial o por consulta real) · **DECISIÓN DEL PROYECTO** · **PROPUESTA** (a validar) · **SUPOSICIÓN/PENDIENTE** (no comprobado).

## 1. Visión general

**DATO CONFIRMADO:**
- MovieLens es un servicio de recomendación de películas, publicado por **GroupLens Research** (Dept. de Ciencias de la Computación e Ingeniería, Universidad de Minnesota, activo desde 1992).
- El dataset ml-25m contiene actividad real (no sintética): 25.000.095 ratings y 1.093.360 tags sobre 62.423 películas, de 162.541 usuarios, entre el 9 de enero de 1995 y el 21 de noviembre de 2019.
- Uso permitido: investigación, con obligación de citar el paper de Harper & Konstan (2015) y prohibición de uso comercial sin permiso.
- **No incluye información demográfica** de usuarios — cada usuario es solo un ID anonimizado.
- Solo incluye películas con al menos un rating o un tag — no es un catálogo completo de cine.
- Los `movieId`/`pelicula_id` son consistentes entre ratings, tags, movies y links. Los `userId`/`usuario_id` son consistentes entre ratings y tags.

## 2. Estudio archivo por archivo

### 2.1 `calificaciones` (ratings.csv) — ✅ Analizado

**Propósito:** registra cada calificación que un usuario dio a una película.

**Granularidad:** una fila = una calificación de un usuario a una película en un momento dado (es un evento, no una entidad).

**Columnas reales en nuestra BD:**

| Columna | Tipo | Descripción |
|---|---|---|
| usuario_id | INT | ID anonimizado del usuario |
| pelicula_id | INT | ID de la película calificada |
| calificacion | DECIMAL(3,1) | 0.5 a 5.0 estrellas, incrementos de 0.5 |
| fecha_timestamp | BIGINT | Segundos desde 1970-01-01 UTC (epoch Unix) |

**Volumen confirmado:** 25.000.095 filas, 1245 MB en disco (ver `docs/volumetria.md`).

**Relaciones:** N calificaciones → 1 película. No existe tabla de usuarios en el dataset original — el usuario solo existe como ID.

**Pendiente de verificar:**
- ¿Existen calificaciones duplicadas (mismo usuario_id + pelicula_id más de una vez)?
- ¿El rango real de fecha_timestamp coincide con 1995–2019?
- ¿Hay valores de calificacion fuera de 0.5–5.0 o nulos?

**Propuesta de modelado en discusión (no decisión final):**
- Futura dimensión Usuario con clave subrogada (`usuario_key`) + clave natural (`usuario_id`), complementada con atributos derivados de calificaciones (primera calificación, última calificación, promedio) y de etiquetas (cantidad de tags puestos). Estos atributos no existen en el CSV, se calculan agregando — implica que se calculan en una capa posterior a Bronze.
- `calificacion` es candidato claro a métrica de hecho; `usuario_id`/`pelicula_id` son candidatos a claves foráneas hacia dimensiones.

### 2.2 `peliculas` (movies.csv) — ⏳ Pendiente de analizar

**Estructura real:** `pelicula_id INT PRIMARY KEY, titulo VARCHAR(300), generos VARCHAR(200)`
- `titulo` incluye el año de estreno entre paréntesis; puede tener errores/inconsistencias (advertido en el README oficial).
- `generos` es una lista separada por `|`.
- Confirmado por consulta: 62.423 filas.

### 2.3 `etiquetas` (tags.csv) — ⏳ Pendiente de analizar

**Estructura real:** `usuario_id INT, pelicula_id INT, etiqueta VARCHAR(255), fecha_timestamp BIGINT`
- `etiqueta` = texto libre definido por el usuario, sin vocabulario controlado.
- Confirmado por consulta: 1.093.360 filas.

### 2.4 `enlaces` (links.csv) — ⏳ Pendiente de analizar

**Estructura real:** `pelicula_id INT PRIMARY KEY, imdb_id VARCHAR(20), tmdb_id INT`
- Confirmado por consulta: 62.423 filas — igual a `peliculas`, indicio de relación 1 a 1 (pendiente de confirmar sin excepciones).

### 2.5 `genoma_puntuaciones` (genome-scores.csv) — ⏳ Pendiente de analizar

**Estructura real:** `pelicula_id INT, tag_id INT, relevancia DECIMAL(6,5)`
- El README la describe como "matriz densa". Confirmado por consulta: 15.584.448 filas — menor que el máximo teórico de 70.413.624 (62.423 × 1.128). Contradicción a investigar cuando se estudie este archivo a fondo.

### 2.6 `genoma_etiquetas` (genome-tags.csv) — ⏳ Pendiente de analizar

**Estructura real:** `tag_id INT PRIMARY KEY, etiqueta VARCHAR(255)`
- Diccionario que traduce los tag_id del genoma a texto legible. Confirmado por consulta: 1.128 filas.

## 3. Próximos pasos

- Analizar a fondo `peliculas`, `etiquetas`, `enlaces`, `genoma_puntuaciones` y `genoma_etiquetas` con el mismo nivel de detalle que `calificaciones`.
- Verificar con SQL las dudas de calidad pendientes en `calificaciones`.
- Investigar la discrepancia de `genoma_puntuaciones` frente a la "matriz densa" declarada.