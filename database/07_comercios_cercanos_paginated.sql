-- ==============================================================================
-- ACGeneric - Función para obtener comercios ordenados por distancia con paginación
-- ==============================================================================
-- Este script crea una función RPC para ser llamada desde la API
-- Requisitos: Cargar todos los comercios ordenados por distancia
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_comercios_sorted_by_distance(
  user_lat DOUBLE PRECISION,
  user_long DOUBLE PRECISION,
  page_number INTEGER DEFAULT 1,
  page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  nombre TEXT,
  direccion TEXT,
  telefono TEXT,
  horario TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  imagen_url TEXT,
  categorias TEXT[],
  distancia_km NUMERIC,
  total_count BIGINT
) AS $$
DECLARE
  offset_val INTEGER;
BEGIN
  -- Calcular offset
  offset_val := (page_number - 1) * page_size;

  RETURN QUERY
  WITH calculated_distances AS (
    SELECT 
      c.id,
      c.nombre,
      c.direccion,
      c.telefono,
      c.horario,
      c.latitud,
      c.longitud,
      c.imagen_url,
      c.categorias,
      ROUND(
        (ST_Distance(
          c.location,
          ST_MakePoint(user_long, user_lat)::geography
        ) / 1000)::numeric,
        2
      ) AS distancia_km
    FROM public.comercios c
    WHERE c.is_approved = true
  ),
  total_records AS (
    SELECT COUNT(*) AS count FROM calculated_distances
  )
  SELECT 
    cd.id,
    cd.nombre,
    cd.direccion,
    cd.telefono,
    cd.horario,
    cd.latitud,
    cd.longitud,
    cd.imagen_url,
    cd.categorias,
    cd.distancia_km,
    tr.count AS total_count
  FROM calculated_distances cd
  CROSS JOIN total_records tr
  ORDER BY cd.distancia_km ASC
  LIMIT page_size
  OFFSET offset_val;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_comercios_sorted_by_distance IS 
  'Obtiene comercios activos ordenados por distancia al usuario, con paginación y conteo total. Incluye detalles de contacto.';
