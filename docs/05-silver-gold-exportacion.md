# Silver completa, Gold y exportación (18 oct 2026)

## Estado
| Capa | Estado | Evidencia |
|---|---|---|
| Bronce | Implementada | 6 tablas, 41.803.877 filas |
| Plata | Implementada (11 de 11 tablas) | PK en 4 tablas de hechos/puente y 12 FK verificadas en pg_constraint |
| Oro | Implementada: 12 vistas materializadas | 3 de Ivan + 9 nuevas; 20 de 21 requerimientos cubiertos (USR-03 pendiente) |
| Exportación | Implementada | etl/export/exportar_gold.py: 12 CSV y 11 hojas de Google Sheets |
| Tableau | Planificado | dashboards sobre los CSV de Gold |

## Carga de Silver (cifras medidas)
| Tabla | Filas |
|---|---|
| dim_genero | 20 (19 géneros + "Sin género"; IMAX con tipo "formato") |
| puente_pelicula_genero | 112.307 pares, 62.423 películas |
| dim_etiqueta | 65.413 (73.051 textos distintos antes de normalizar) |
| hechos_etiquetas | 1.093.359 |
| dim_genoma_tag | 1.128 |
| hechos_genoma | 15.584.448 (= 13.816 películas × 1.128 tags) |

## Decisiones
- DECISIÓN: normalizar etiquetas con lower+trim. Al aplicarla, 1 fila de Bronce
  (1.093.360) colapsó con otra del mismo usuario y película que solo diferían en
  mayúsculas o espacios. Se conserva la más antigua (DISTINCT ON). Por eso Silver
  tiene 1.093.359. Es una pérdida deliberada y medida, no un error de carga.
- DECISIÓN: las PK y FK de los hechos se crean después de la carga masiva
  (más rápido); sin índices adicionales, porque Gold agrega con barridos completos.
- DECISIÓN: las 6 tablas pendientes de Silver estaban vacías y se recrearon con DDL
  propio (script 04, con guardia que aborta si alguna tiene filas).
- DECISIÓN: Gold usa medidas aditivas (conteos, sumas, suma de cuadrados). Los
  promedios y la desviación (poblacional) se derivan de las sumas, nunca se promedian
  promedios.
- DECISIÓN (a confirmar en equipo): TAG-04 usa películas con 100 o más valoraciones
  (mismo umbral de PEL-02).
- DECISIÓN: solo se exportan agregados (licencia del dataset). Películas: 100 o más
  valoraciones (10.326). Usuarios: 12 filas por decil y segmento. tags_top solo CSV.
- DECISIÓN: CSV es la salida base; Google Sheets es opcional (--sheets).

## Validación
- Restricciones: 1 PK por tabla; FK 4/4/2/2 (hechos_calificaciones, hechos_etiquetas,
  hechos_genoma, puente).
- Gold: la suma de valoraciones es 25.000.095. Total 88.346.697, media 3,53, mediana
  3,5, y 12.452.811 valoraciones (49,8 %) iguales o superiores a 4.0.
- Genoma: 1.128 correlaciones, una por tag.

## Rendimiento
- Misma consulta (valoraciones y promedio por año): 4.435 ms sobre Silver y 4,4 ms
  sobre Gold (unas 1.000 veces más rápida).
- Creación de vistas Gold nuevas: entre 54 ms y 1 min 14 s (la más lenta, la mediana
  anual sobre 25 M de filas).
- Carga de Silver: hechos_calificaciones 2 min 51 s; hechos_genoma 1 min 6 s;
  PK/FK + ANALYZE 2 min 17 s.

## Pendiente
- USR-03 (géneros distintos por usuario) no tiene vista Gold todavía.
- Dashboards en Tableau Public y storytelling.
- Actualizar el documento final (PDF).