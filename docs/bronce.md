# Capa Bronce — implementación

Convenciones: **DATO CONFIRMADO** (README oficial o consulta real) · **DECISIÓN DEL PROYECTO** · **PROPUESTA** · **SUPOSICIÓN/PENDIENTE**.

## 1. Propósito

La capa Bronce es la zona de aterrizaje (*landing zone*) de la arquitectura Medallion: una copia **1:1** de los 6 CSV originales de MovieLens 25M dentro de PostgreSQL 17, sin transformaciones, limpieza ni eliminación de registros. Todo lo que ocurra después (limpieza, modelo dimensional) parte de ella, y si una transformación posterior falla, Bronce permite repetirla sin volver a los archivos.

## 2. Estructura

**DATO CONFIRMADO.** Base de datos `movielens_db` con tres esquemas: `bronze` (6 tablas, cargadas), `silver` y `gold` (creados, en construcción).

| Archivo CSV | Tabla | Filas | Una fila representa |
|---|---|---:|---|
| movies.csv | `bronze.peliculas` | 62.423 | una película |
| ratings.csv | `bronze.calificaciones` | 25.000.095 | una calificación de un usuario a una película (evento) |
| tags.csv | `bronze.etiquetas` | 1.093.360 | un tag aplicado por un usuario a una película (evento) |
| links.csv | `bronze.enlaces` | 62.423 | los identificadores externos de una película |
| genome-tags.csv | `bronze.genoma_etiquetas` | 1.128 | un tag del genoma |
| genome-scores.csv | `bronze.genoma_puntuaciones` | 15.584.448 | la relevancia de un tag del genoma para una película |
| | **Total** | **41.803.877** | |

## 3. Decisiones de diseño

Todas son **DECISIÓN DEL PROYECTO**.

| # | Decisión | Justificación |
|---|---|---|
| D1 | Una sola base con tres esquemas (`bronze`, `silver`, `gold`) en lugar de tres bases | PostgreSQL no consulta entre bases sin extensiones; con esquemas, el ETL es `INSERT INTO silver… SELECT … FROM bronze…` |
| D2 | Todo objeto se referencia con su esquema (`bronze.tabla`); no se usa `search_path` | Explícito y seguro: el mismo script no puede apuntar a otra tabla según la sesión |
| D3 | Sin claves foráneas en Bronce | La integridad referencial se valida en el EDA y se impone en Silver; imponerla aquí podría hacer fallar la carga por problemas de calidad aún no conocidos |
| D4 | Clave primaria solo en las tablas de catálogo con clave natural única: `peliculas`, `enlaces`, `genoma_etiquetas` | Garantiza unicidad donde es cierta. Las tablas de eventos (`calificaciones`, `etiquetas`, `genoma_puntuaciones`) no llevan PK ni índices: carga más rápida; se indexa en Silver |
| D5 | Tipos fieles al CSV: `fecha_timestamp` como `BIGINT` (segundos UNIX, UTC), `imdb_id` como texto | La conversión a fecha ocurre en Silver; Bronce no interpreta |
| D6 | Carga atómica, repetible y autoverificada con `COPY` del servidor | Ver sección 5 |
| D7 | Diccionario de datos dentro de la BD (`COMMENT ON` en tablas y columnas) | Queda con los datos, se ve en pgAdmin y no se desactualiza |
| D8 | Descripciones de `COMMENT ON` sin tildes | Evita caracteres corruptos si la consola envía otra codificación |

## 4. Scripts y orden de ejecución

| Orden | Script | Función |
|---|---|---|
| 1 | `database/00_crear_esquemas.sql` | Crea los esquemas `bronze`, `silver`, `gold` con su descripción |
| 2 | `database/01_tablas_bronze.sql` | Crea las 6 tablas y su diccionario de datos |
| 3 | `etl/bronze/02_cargar_bronze.sql` | Carga los 6 CSV (vacía → copia → verifica conteo) |
| 4 | `scripts/verificacion_volumetria.sql` | Comprueba conteos contra lo esperado y mide el peso en disco |

La base `movielens_db` se crea una sola vez (`CREATE DATABASE movielens_db;`) conectado a otra base; no forma parte de los scripts repetibles porque PostgreSQL no permite `CREATE DATABASE` dentro de una transacción ni con `IF NOT EXISTS`.

## 5. Garantías de la carga

- **Atómica:** el bloque de carga es una sola transacción. Si falla cualquier tabla (archivo no encontrado, dato inválido o conteo distinto del esperado), se revierte todo y Bronce queda como estaba.
- **Repetible:** cada tabla se vacía con `TRUNCATE` antes de cargarse, por lo que ejecutar el script varias veces nunca duplica filas.
- **Autoverificada:** compara las filas cargadas con el conteo esperado (README oficial para ratings, tags y movies; mediciones del proyecto para links, genome-scores y genome-tags).

## 6. Cómo reproducirlo desde cero

1. Descargar `ml-25m.zip` desde https://grouplens.org/datasets/movielens/25m/ (el dataset **no** se sube al repositorio: la licencia prohíbe redistribuirlo).
2. Verificar la integridad, como recomienda el README: en Windows, `certutil -hashfile ml-25m.zip MD5` y comparar con el contenido del archivo `.md5` publicado.
3. Descomprimir en `C:/ml-25m/` (o en otra ruta, editando la variable `ruta` de `02_cargar_bronze.sql`).
4. Crear la base `movielens_db` y ejecutar los scripts 1, 2 y 3 en orden, desde pgAdmin (Query Tool) o con `psql -d movielens_db -f <archivo>`.
5. Ejecutar `scripts/verificacion_volumetria.sql`: la columna `coincide` debe ser `true` en todas las filas.

Requisito del `COPY` del servidor: el servicio de PostgreSQL debe poder leer la carpeta del dataset y el rol debe ser superusuario o miembro de `pg_read_server_files`.

## 7. Diccionario de datos

Fuente de las descripciones: README oficial de ml-25m. Se consulta también dentro de la BD con la consulta final de `01_tablas_bronze.sql`.

| Tabla.columna | Tipo | Descripción |
|---|---|---|
| peliculas.pelicula_id | INT, PK | Id de película en MovieLens; consistente entre ratings, tags, movies y links |
| peliculas.titulo | VARCHAR(300) | Título con el año de estreno entre paréntesis; puede contener errores o inconsistencias |
| peliculas.generos | VARCHAR(200) | Géneros separados por `\|`; `(no genres listed)` si no tiene |
| calificaciones.usuario_id | INT | Id anonimizado del usuario; consistente con tags |
| calificaciones.pelicula_id | INT | Película calificada |
| calificaciones.calificacion | DECIMAL(3,1) | Estrellas de 0.5 a 5.0 en incrementos de 0.5 |
| calificaciones.fecha_timestamp | BIGINT | Segundos desde 1970-01-01 00:00:00 UTC |
| etiquetas.usuario_id | INT | Usuario que aplicó el tag |
| etiquetas.pelicula_id | INT | Película etiquetada |
| etiquetas.etiqueta | VARCHAR(255) | Texto libre; su significado lo define cada usuario |
| etiquetas.fecha_timestamp | BIGINT | Segundos desde 1970-01-01 00:00:00 UTC |
| enlaces.pelicula_id | INT, PK | Id de película en MovieLens |
| enlaces.imdb_id | VARCHAR(20) | Identificador en IMDb, conservado como texto |
| enlaces.tmdb_id | INT, admite NULL | Identificador en TMDb |
| genoma_etiquetas.tag_id | INT, PK | Id del tag del genoma; se genera al exportar y puede variar entre versiones |
| genoma_etiquetas.etiqueta | VARCHAR(255) | Descripción del tag del genoma |
| genoma_puntuaciones.pelicula_id | INT | Película (solo las cubiertas por el genoma) |
| genoma_puntuaciones.tag_id | INT | Tag del genoma |
| genoma_puntuaciones.relevancia | DECIMAL(6,5) | Relevancia del tag para la película; valores observados entre 0.00025 y 1.0 |

## 8. Limitaciones y pendientes conocidos

- **Fidelidad de `relevancia` (PENDIENTE):** un `DECIMAL(6,5)` redondea en silencio si el CSV tuviera más de 5 decimales, y desde Bronce ya no se puede detectar. Verificación posible contra el CSV original: cargar la columna como texto en una tabla temporal y buscar valores con 6 o más decimales:

  ```sql
  CREATE TEMP TABLE t_gs (pelicula_id text, tag_id text, relevancia text);
  COPY t_gs FROM 'C:/ml-25m/genome-scores.csv' WITH (FORMAT csv, HEADER true);
  SELECT COUNT(*) AS con_mas_de_5_decimales FROM t_gs WHERE relevancia ~ '\.\d{6,}$';
  DROP TABLE t_gs;
  ```
- **Sin registro persistente de cargas:** el avance se informa con mensajes (`NOTICE`) pero no se guarda en una tabla de control (fecha, archivo, filas). **PROPUESTA** a evaluar si se necesita auditoría.
- **Ruta del dataset editable a mano** en el script de carga, y dependiente de los permisos del servidor.

## 9. Licencia y citación

**DATO CONFIRMADO (README):** uso permitido para investigación, sin redistribución de los datos sin permiso, sin uso comercial sin autorización, y obligación de citar:

> F. Maxwell Harper y Joseph A. Konstan. 2015. *The MovieLens Datasets: History and Context.* ACM Transactions on Interactive Intelligent Systems (TiiS) 5, 4: 19:1–19:19. https://doi.org/10.1145/2827872

Para los datos del Tag Genome, citar además: Jesse Vig, Shilad Sen y John Riedl. 2012. *The Tag Genome: Encoding Community Knowledge to Support Novel Interaction.* ACM TiiS 2, 3: 13:1–13:44. https://doi.org/10.1145/2362394.2362395