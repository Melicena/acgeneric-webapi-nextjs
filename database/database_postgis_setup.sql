-- ==============================================================================
-- ACGeneric - Configuración de PostGIS para Consultas Geoespaciales
-- ==============================================================================
-- Este script configura PostGIS para búsquedas de comercios por ubicación
-- Requisitos: RF-020 (Exploración de ofertas), RF-021 (Vista de mapa)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. HABILITAR EXTENSIÓN POSTGIS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verificar instalación
SELECT PostGIS_Version();

COMMENT ON EXTENSION postgis IS 
  'Extensión para consultas geoespaciales (búsqueda por radio, distancias, mapas)';

-- -----------------------------------------------------------------------------
-- 2. AÑADIR COLUMNA GEOESPACIAL A COMERCIOS
-- -----------------------------------------------------------------------------

-- Añadir columna location de tipo GEOGRAPHY
ALTER TABLE comercios 
ADD COLUMN IF NOT EXISTS location GEOGRAPHY(Point, 4326);

COMMENT ON COLUMN comercios.location IS 
  'Ubicación geográfica del comercio (SRID 4326 = GPS estándar WGS 84). Usado para búsquedas por radio y cálculo de distancias.';

-- -----------------------------------------------------------------------------
-- 3. CREAR ÍNDICE GIST PARA BÚSQUEDAS EFICIENTES
-- -----------------------------------------------------------------------------

-- Índice espacial GIST (Generalized Search Tree)
-- Reduce tiempo de búsqueda de segundos a milisegundos
CREATE INDEX IF NOT EXISTS idx_comercios_location 
ON comercios USING GIST (location);

COMMENT ON INDEX idx_comercios_location IS 
  'Índice GIST para búsquedas geoespaciales eficientes (ST_DWithin, ST_Distance)';

-- -----------------------------------------------------------------------------
-- 4. POBLAR COLUMNA LOCATION DESDE LAT/LONG EXISTENTES
-- -----------------------------------------------------------------------------

-- Convertir latitud/longitud a columna location
UPDATE comercios 
SET location = ST_MakePoint(longitud, latitud)::geography
WHERE location IS NULL 
  AND latitud IS NOT NULL 
  AND longitud IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: SINCRONIZACIÓN AUTOMÁTICA DE UBICACIÓN
-- -----------------------------------------------------------------------------

-- Función para mantener sincronizadas location, latitud y longitud
CREATE OR REPLACE FUNCTION sync_comercio_location()
RETURNS TRIGGER AS $$
BEGIN
  -- Si se actualizan latitud o longitud, actualizar location
  IF (NEW.latitud IS NOT NULL AND NEW.longitud IS NOT NULL) THEN
    NEW.location = ST_MakePoint(NEW.longitud, NEW.latitud)::geography;
  END IF;
  
  -- Si se actualiza location, actualizar latitud y longitud
  IF (NEW.location IS NOT NULL AND 
      (OLD.location IS NULL OR NEW.location != OLD.location)) THEN
    NEW.latitud = ST_Y(NEW.location::geometry);
    NEW.longitud = ST_X(NEW.location::geometry);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para INSERT y UPDATE
DROP TRIGGER IF EXISTS sync_location_trigger ON comercios;
CREATE TRIGGER sync_location_trigger
  BEFORE INSERT OR UPDATE ON comercios
  FOR EACH ROW
  EXECUTE FUNCTION sync_comercio_location();

COMMENT ON FUNCTION sync_comercio_location() IS 
  'Mantiene sincronizadas las columnas location (GEOGRAPHY) con latitud/longitud (DOUBLE PRECISION)';

COMMENT ON TRIGGER sync_location_trigger ON comercios IS 
  'Sincroniza automáticamente location con lat/long en cada INSERT/UPDATE';

-- -----------------------------------------------------------------------------
-- 6. FUNCIONES HELPER PARA CONSULTAS COMUNES
-- -----------------------------------------------------------------------------

-- Función: Buscar comercios en un radio
CREATE OR REPLACE FUNCTION buscar_comercios_cercanos(
  user_lat DOUBLE PRECISION,
  user_long DOUBLE PRECISION,
  radio_metros INTEGER DEFAULT 5000,
  limite INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  nombre TEXT,
  direccion TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  distancia_km NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.nombre,
    c.direccion,
    c.latitud,
    c.longitud,
    ROUND(
      (ST_Distance(
        c.location,
        ST_MakePoint(user_long, user_lat)::geography
      ) / 1000)::numeric,
      2
    ) AS distancia_km
  FROM comercios c
  WHERE 
    c.is_approved = true
    AND ST_DWithin(
      c.location,
      ST_MakePoint(user_long, user_lat)::geography,
      radio_metros
    )
  ORDER BY distancia_km
  LIMIT limite;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION buscar_comercios_cercanos IS 
  'Busca comercios aprobados en un radio específico desde una ubicación. Ejemplo: SELECT * FROM buscar_comercios_cercanos(40.4168, -3.7038, 5000, 50);';

-- Función: Buscar ofertas cercanas
CREATE OR REPLACE FUNCTION buscar_ofertas_cercanas(
  user_lat DOUBLE PRECISION,
  user_long DOUBLE PRECISION,
  radio_metros INTEGER DEFAULT 10000,
  categoria_filtro TEXT DEFAULT NULL,
  limite INTEGER DEFAULT 100
)
RETURNS TABLE (
  oferta_id UUID,
  titulo TEXT,
  descripcion TEXT,
  comercio_nombre TEXT,
  comercio_direccion TEXT,
  distancia_km NUMERIC,
  fecha_fin TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS oferta_id,
    o.titulo,
    o.descripcion,
    c.nombre AS comercio_nombre,
    c.direccion AS comercio_direccion,
    ROUND(
      (ST_Distance(
        c.location,
        ST_MakePoint(user_long, user_lat)::geography
      ) / 1000)::numeric,
      2
    ) AS distancia_km,
    o.fecha_fin
  FROM ofertas o
  JOIN comercios c ON o.comercio = c.id
  WHERE 
    c.is_approved = true
    AND o.fecha_inicio <= NOW()
    AND o.fecha_fin >= NOW()
    AND ST_DWithin(
      c.location,
      ST_MakePoint(user_long, user_lat)::geography,
      radio_metros
    )
    AND (categoria_filtro IS NULL OR categoria_filtro = ANY(c.categorias))
  ORDER BY distancia_km, o.created_at DESC
  LIMIT limite;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION buscar_ofertas_cercanas IS 
  'Busca ofertas activas en un radio desde una ubicación, con filtro opcional por categoría. Ejemplo: SELECT * FROM buscar_ofertas_cercanas(40.4168, -3.7038, 10000, ''Restaurante'', 50);';

-- -----------------------------------------------------------------------------
-- 7. VISTAS ÚTILES
-- -----------------------------------------------------------------------------

-- Vista: Comercios con ubicación completa
CREATE OR REPLACE VIEW comercios_con_ubicacion AS
SELECT 
  id,
  nombre,
  direccion,
  telefono,
  latitud,
  longitud,
  ST_Y(location::geometry) AS lat_from_location,
  ST_X(location::geometry) AS long_from_location,
  categorias,
  is_approved
FROM comercios
WHERE location IS NOT NULL;

COMMENT ON VIEW comercios_con_ubicacion IS 
  'Vista de comercios con datos de ubicación completos para debugging';

-- -----------------------------------------------------------------------------
-- 8. DATOS DE PRUEBA (Opcional - Comentar si no se desea)
-- -----------------------------------------------------------------------------

-- Insertar comercios de ejemplo en Madrid
/*
INSERT INTO comercios (nombre, direccion, telefono, horario, latitud, longitud, imagen_url, is_approved)
VALUES 
  ('Restaurante Sol', 'Puerta del Sol, 1', '911234567', 'L-D 10:00-22:00', 40.4168, -3.7038, 'https://example.com/sol.jpg', true),
  ('Cafetería Retiro', 'Parque del Retiro, s/n', '912345678', 'L-D 08:00-20:00', 40.4153, -3.6844, 'https://example.com/retiro.jpg', true),
  ('Tienda Gran Vía', 'Gran Vía, 25', '913456789', 'L-S 10:00-21:00', 40.4200, -3.7050, 'https://example.com/granvia.jpg', true);

-- Verificar que se creó la columna location automáticamente (por el trigger)
SELECT nombre, latitud, longitud, location FROM comercios;
*/

-- -----------------------------------------------------------------------------
-- 9. TESTING
-- -----------------------------------------------------------------------------

-- Test 1: Verificar que PostGIS está activo
DO $$
BEGIN
  IF (SELECT PostGIS_Version()) IS NOT NULL THEN
    RAISE NOTICE '✓ PostGIS está instalado correctamente';
  ELSE
    RAISE EXCEPTION '✗ PostGIS no está instalado';
  END IF;
END $$;

-- Test 2: Verificar que el índice GIST existe
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_comercios_location'
  ) THEN
    RAISE NOTICE '✓ Índice GIST creado correctamente';
  ELSE
    RAISE WARNING '✗ Índice GIST no encontrado';
  END IF;
END $$;

-- Test 3: Verificar que el trigger existe
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'sync_location_trigger'
  ) THEN
    RAISE NOTICE '✓ Trigger de sincronización activo';
  ELSE
    RAISE WARNING '✗ Trigger de sincronización no encontrado';
  END IF;
END $$;

-- Test 4: Ejemplo de búsqueda (requiere datos)
/*
-- Buscar comercios en 5km desde Puerta del Sol, Madrid
SELECT * FROM buscar_comercios_cercanos(40.4168, -3.7038, 5000, 10);

-- Buscar ofertas en 10km desde Retiro, Madrid
SELECT * FROM buscar_ofertas_cercanas(40.4153, -3.6844, 10000, NULL, 20);
*/

-- ==============================================================================
-- NOTAS DE USO
-- ==============================================================================
--
-- CONSULTAS BÁSICAS:
--
-- 1. Buscar comercios cercanos:
--    SELECT * FROM buscar_comercios_cercanos(40.4168, -3.7038, 5000, 50);
--
-- 2. Buscar ofertas cercanas:
--    SELECT * FROM buscar_ofertas_cercanas(40.4168, -3.7038, 10000, 'Restaurante', 100);
--
-- 3. Calcular distancia entre dos puntos:
--    SELECT ST_Distance(
--      ST_MakePoint(-3.7038, 40.4168)::geography,
--      ST_MakePoint(-0.3763, 39.4699)::geography
--    ) / 1000 AS distancia_km;
--
-- 4. Comercios en viewport del mapa:
--    SELECT * FROM comercios
--    WHERE location && ST_MakeEnvelope(-3.8, 40.3, -3.6, 40.5, 4326)::geography;
--
-- ==============================================================================
-- RENDIMIENTO
-- ==============================================================================
--
-- Con índice GIST:
-- - Búsqueda en 10,000 comercios: ~50-100ms
-- - Sin índice: ~2-3 segundos
--
-- Mejores prácticas:
-- 1. Siempre usar ST_DWithin antes de ST_Distance
-- 2. Limitar resultados con LIMIT
-- 3. Usar GEOGRAPHY para distancias reales (no GEOMETRY)
-- 4. Mantener índice GIST actualizado
--
-- ==============================================================================
