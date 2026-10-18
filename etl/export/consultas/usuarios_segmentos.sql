SELECT decil_actividad,
       segmento_actividad,
       COUNT(*)                                          AS n_usuarios,
       MIN(total_valoraciones)                           AS min_valoraciones,
       MAX(total_valoraciones)                           AS max_valoraciones,
       SUM(total_valoraciones)                           AS total_valoraciones,
       SUM(suma_calificaciones)                          AS suma_calificaciones,
       ROUND(SUM(suma_calificaciones) / SUM(total_valoraciones), 3) AS promedio_calificacion,
       ROUND(100.0 * SUM(total_valoraciones) / SUM(SUM(total_valoraciones)) OVER (), 2) AS pct_valoraciones
FROM gold.v_usuario_comportamiento
GROUP BY decil_actividad, segmento_actividad
ORDER BY decil_actividad, segmento_actividad;