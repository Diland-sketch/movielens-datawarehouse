SET maintenance_work_mem = '1900MB';  -- acelera la construcción de índices (ajuste a su RAM)

-- ===== hechos_calificaciones =====
ALTER TABLE silver.hechos_calificaciones DROP CONSTRAINT IF EXISTS pk_hechos_calificaciones;
ALTER TABLE silver.hechos_calificaciones ADD CONSTRAINT pk_hechos_calificaciones PRIMARY KEY (usuario_key, pelicula_key);
ALTER TABLE silver.hechos_calificaciones DROP CONSTRAINT IF EXISTS fk_hcal_usuario;
ALTER TABLE silver.hechos_calificaciones ADD CONSTRAINT fk_hcal_usuario  FOREIGN KEY (usuario_key)  REFERENCES silver.dim_usuario(usuario_key);
ALTER TABLE silver.hechos_calificaciones DROP CONSTRAINT IF EXISTS fk_hcal_pelicula;
ALTER TABLE silver.hechos_calificaciones ADD CONSTRAINT fk_hcal_pelicula FOREIGN KEY (pelicula_key) REFERENCES silver.dim_pelicula(pelicula_key);
ALTER TABLE silver.hechos_calificaciones DROP CONSTRAINT IF EXISTS fk_hcal_tiempo;
ALTER TABLE silver.hechos_calificaciones ADD CONSTRAINT fk_hcal_tiempo   FOREIGN KEY (tiempo_key)   REFERENCES silver.dim_tiempo(tiempo_key);
ALTER TABLE silver.hechos_calificaciones DROP CONSTRAINT IF EXISTS fk_hcal_hora;
ALTER TABLE silver.hechos_calificaciones ADD CONSTRAINT fk_hcal_hora     FOREIGN KEY (hora_key)     REFERENCES silver.dim_hora(hora_key);

-- ===== hechos_etiquetas =====
ALTER TABLE silver.hechos_etiquetas DROP CONSTRAINT IF EXISTS pk_hechos_etiquetas;
ALTER TABLE silver.hechos_etiquetas ADD CONSTRAINT pk_hechos_etiquetas PRIMARY KEY (usuario_key, pelicula_key, etiqueta_key);
ALTER TABLE silver.hechos_etiquetas DROP CONSTRAINT IF EXISTS fk_het_usuario;
ALTER TABLE silver.hechos_etiquetas ADD CONSTRAINT fk_het_usuario  FOREIGN KEY (usuario_key)  REFERENCES silver.dim_usuario(usuario_key);
ALTER TABLE silver.hechos_etiquetas DROP CONSTRAINT IF EXISTS fk_het_pelicula;
ALTER TABLE silver.hechos_etiquetas ADD CONSTRAINT fk_het_pelicula FOREIGN KEY (pelicula_key) REFERENCES silver.dim_pelicula(pelicula_key);
ALTER TABLE silver.hechos_etiquetas DROP CONSTRAINT IF EXISTS fk_het_etiqueta;
ALTER TABLE silver.hechos_etiquetas ADD CONSTRAINT fk_het_etiqueta FOREIGN KEY (etiqueta_key) REFERENCES silver.dim_etiqueta(etiqueta_key);
ALTER TABLE silver.hechos_etiquetas DROP CONSTRAINT IF EXISTS fk_het_tiempo;
ALTER TABLE silver.hechos_etiquetas ADD CONSTRAINT fk_het_tiempo   FOREIGN KEY (tiempo_key)   REFERENCES silver.dim_tiempo(tiempo_key);

-- ===== hechos_genoma =====
ALTER TABLE silver.hechos_genoma DROP CONSTRAINT IF EXISTS pk_hechos_genoma;
ALTER TABLE silver.hechos_genoma ADD CONSTRAINT pk_hechos_genoma PRIMARY KEY (pelicula_key, genoma_tag_key);
ALTER TABLE silver.hechos_genoma DROP CONSTRAINT IF EXISTS fk_hgen_pelicula;
ALTER TABLE silver.hechos_genoma ADD CONSTRAINT fk_hgen_pelicula FOREIGN KEY (pelicula_key)   REFERENCES silver.dim_pelicula(pelicula_key);
ALTER TABLE silver.hechos_genoma DROP CONSTRAINT IF EXISTS fk_hgen_tag;
ALTER TABLE silver.hechos_genoma ADD CONSTRAINT fk_hgen_tag      FOREIGN KEY (genoma_tag_key) REFERENCES silver.dim_genoma_tag(genoma_tag_key);

-- ===== puente =====
ALTER TABLE silver.puente_pelicula_genero DROP CONSTRAINT IF EXISTS pk_puente_pelicula_genero;
ALTER TABLE silver.puente_pelicula_genero ADD CONSTRAINT pk_puente_pelicula_genero PRIMARY KEY (pelicula_key, genero_key);
ALTER TABLE silver.puente_pelicula_genero DROP CONSTRAINT IF EXISTS fk_pue_pelicula;
ALTER TABLE silver.puente_pelicula_genero ADD CONSTRAINT fk_pue_pelicula FOREIGN KEY (pelicula_key) REFERENCES silver.dim_pelicula(pelicula_key);
ALTER TABLE silver.puente_pelicula_genero DROP CONSTRAINT IF EXISTS fk_pue_genero;
ALTER TABLE silver.puente_pelicula_genero ADD CONSTRAINT fk_pue_genero   FOREIGN KEY (genero_key)   REFERENCES silver.dim_genero(genero_key);

-- Estadísticas para el planificador (importante antes de crear Gold)
ANALYZE silver.hechos_calificaciones;
ANALYZE silver.hechos_etiquetas;
ANALYZE silver.hechos_genoma;
ANALYZE silver.puente_pelicula_genero;

SELECT conrelid::regclass AS tabla,
       COUNT(*) FILTER (WHERE contype = 'p') AS pk,
       COUNT(*) FILTER (WHERE contype = 'f') AS fk
FROM pg_constraint
WHERE connamespace = 'silver'::regnamespace
  AND conrelid::regclass::text IN ('silver.hechos_calificaciones','silver.hechos_etiquetas',
                                   'silver.hechos_genoma','silver.puente_pelicula_genero')
GROUP BY conrelid ORDER BY 1;