-- ==============================================================================
-- TABLA: comercios
-- ==============================================================================
-- Almacena información de negocios/comercios que publican ofertas
-- Incluye ubicación geoespacial con PostGIS para búsquedas por cercanía
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comercios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  direccion TEXT NOT NULL,
  telefono TEXT NOT NULL,
  horario TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL, -- Ubicación geoespacial (PostGIS)
  latitud DOUBLE PRECISION NOT NULL,
  longitud DOUBLE PRECISION NOT NULL,
  imagen_url TEXT NOT NULL, -- Logo del negocio
  personal TEXT[] DEFAULT '{}', -- Array de IDs de empleados
  categorias TEXT[], -- Categorías: "Restaurante", "Tienda de ropa", etc.
  cif TEXT, -- CIF/NIF del negocio
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'trial')),
  is_approved BOOLEAN DEFAULT false, -- Para moderación (RF-007)
  owner_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL, -- Dueño del negocio
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.comercios IS 
  'Negocios/comercios que publican ofertas en la plataforma';

COMMENT ON COLUMN public.comercios.location IS 
  'Ubicación geográfica (PostGIS GEOGRAPHY Point, SRID 4326 = GPS WGS 84). Usado para búsquedas por radio.';

COMMENT ON COLUMN public.comercios.latitud IS 
  'Latitud (redundante para compatibilidad). Sincronizada con location mediante trigger.';

COMMENT ON COLUMN public.comercios.longitud IS 
  'Longitud (redundante para compatibilidad). Sincronizada con location mediante trigger.';

COMMENT ON COLUMN public.comercios.is_approved IS 
  'Si el negocio ha sido aprobado por un admin (RF-007). Solo negocios aprobados pueden publicar ofertas.';

COMMENT ON COLUMN public.comercios.subscription_status IS 
  'Estado de suscripción individual del negocio (puede ser heredado de asociación)';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
-- Índice geoespacial GIST (esencial para búsquedas por radio)
CREATE INDEX IF NOT EXISTS idx_comercios_location ON public.comercios USING GIST (location);

-- Índices estándar
CREATE INDEX IF NOT EXISTS idx_comercios_owner_id ON public.comercios(owner_id);
CREATE INDEX IF NOT EXISTS idx_comercios_is_approved ON public.comercios(is_approved);
CREATE INDEX IF NOT EXISTS idx_comercios_subscription_status ON public.comercios(subscription_status);
CREATE INDEX IF NOT EXISTS idx_comercios_created_at ON public.comercios(created_at DESC);

-- Índice GIN para búsquedas en categorías
CREATE INDEX IF NOT EXISTS idx_comercios_categorias ON public.comercios USING GIN(categorias);

-- Índice de texto completo para búsqueda
CREATE INDEX IF NOT EXISTS idx_comercios_nombre_trgm ON public.comercios USING GIN (nombre gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_comercios_descripcion_trgm ON public.comercios USING GIN (descripcion gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_comercios_updated_at ON public.comercios;
CREATE TRIGGER update_comercios_updated_at
  BEFORE UPDATE ON public.comercios
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.comercios ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede ver comercios aprobados (público)
DROP POLICY IF EXISTS "Comercios aprobados son públicos" ON public.comercios;
CREATE POLICY "Comercios aprobados son públicos"
  ON public.comercios
  FOR SELECT
  USING (is_approved = true);

-- Política: Los dueños pueden ver sus propios comercios (aprobados o no)
DROP POLICY IF EXISTS "Dueños pueden ver sus comercios" ON public.comercios;
CREATE POLICY "Dueños pueden ver sus comercios"
  ON public.comercios
  FOR SELECT
  USING (owner_id = auth.uid());

-- Política: Los dueños pueden actualizar sus comercios
DROP POLICY IF EXISTS "Dueños pueden actualizar sus comercios" ON public.comercios;
CREATE POLICY "Dueños pueden actualizar sus comercios"
  ON public.comercios
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Política: Usuarios con rol BUSINESS_OWNER pueden crear comercios
DROP POLICY IF EXISTS "Business owners pueden crear comercios" ON public.comercios;
CREATE POLICY "Business owners pueden crear comercios"
  ON public.comercios
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'BUSINESS_OWNER'
    )
  );

-- Política: Admins pueden ver todos los comercios
DROP POLICY IF EXISTS "Admins pueden ver todos los comercios" ON public.comercios;
CREATE POLICY "Admins pueden ver todos los comercios"
  ON public.comercios
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
    )
  );

-- Política: Admins pueden actualizar cualquier comercio (moderación)
DROP POLICY IF EXISTS "Admins pueden actualizar comercios" ON public.comercios;
CREATE POLICY "Admins pueden actualizar comercios"
  ON public.comercios
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
    )
  );

-- -----------------------------------------------------------------------------
-- 6. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Buscar comercios cercanos (usa PostGIS)
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
  categorias TEXT[],
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
    c.categorias,
    ROUND(
      (ST_Distance(
        c.location,
        ST_MakePoint(user_long, user_lat)::geography
      ) / 1000)::numeric,
      2
    ) AS distancia_km
  FROM public.comercios c
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION buscar_comercios_cercanos IS 
  'Busca comercios aprobados en un radio desde una ubicación. Ejemplo: SELECT * FROM buscar_comercios_cercanos(40.4168, -3.7038, 5000, 50);';

-- Función: Verificar si comercio está aprobado
CREATE OR REPLACE FUNCTION is_comercio_approved(comercio_id UUID)
RETURNS BOOLEAN AS $$
  SELECT is_approved FROM public.comercios WHERE id = comercio_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Obtener comercios de un usuario
CREATE OR REPLACE FUNCTION get_comercios_by_owner(owner_user_id UUID)
RETURNS SETOF public.comercios AS $$
  SELECT * FROM public.comercios WHERE owner_id = owner_user_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT ON public.comercios TO anon, authenticated;
GRANT INSERT, UPDATE ON public.comercios TO authenticated;
GRANT DELETE ON public.comercios TO authenticated; -- Controlado por RLS

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'comercios'
) AS table_exists;

-- Verificar que PostGIS está habilitado
SELECT PostGIS_Version();

-- Verificar que el índice GIST existe
SELECT EXISTS (
  SELECT FROM pg_indexes 
  WHERE tablename = 'comercios' AND indexname = 'idx_comercios_location'
) AS gist_index_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'comercios';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'comercios';
