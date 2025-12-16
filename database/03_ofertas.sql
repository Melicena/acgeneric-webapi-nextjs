-- ==============================================================================
-- TABLA: ofertas
-- ==============================================================================
-- Almacena las ofertas/promociones publicadas por los comercios
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ofertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comercio UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  comercio_id UUID REFERENCES public.comercios(id) ON DELETE SET NULL, -- Comercio (antes user_id)
  titulo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  image_url TEXT NOT NULL, -- Imagen de la oferta
  fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
  nivel_requerido TEXT NOT NULL DEFAULT 'FREE' CHECK (nivel_requerido IN ('FREE', 'PREMIUM', 'VIP')),
  discount_type TEXT CHECK (discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT', 'FREE_ITEM', '2X1')),
  discount_value NUMERIC,
  condiciones TEXT, -- Condiciones de la oferta
  total_views INTEGER DEFAULT 0, -- Contador de visualizaciones
  total_saves INTEGER DEFAULT 0, -- Contador de veces guardada como cupón
  total_redeems INTEGER DEFAULT 0, -- Contador de canjes
  is_active BOOLEAN DEFAULT true, -- Si la oferta está activa
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_dates CHECK (fecha_fin > fecha_inicio),
  CONSTRAINT valid_discount CHECK (
    (discount_type IS NULL AND discount_value IS NULL) OR
    (discount_type IS NOT NULL AND discount_value IS NOT NULL AND discount_value > 0)
  )
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.ofertas IS 
  'Ofertas/promociones publicadas por comercios';

COMMENT ON COLUMN public.ofertas.comercio IS 
  'ID del comercio que publica la oferta';

COMMENT ON COLUMN public.ofertas.nivel_requerido IS 
  'Nivel de suscripción requerido para ver/usar la oferta';

COMMENT ON COLUMN public.ofertas.discount_type IS 
  'Tipo de descuento: PERCENTAGE (%), FIXED_AMOUNT (€), FREE_ITEM (gratis), 2X1';

COMMENT ON COLUMN public.ofertas.total_views IS 
  'Contador de visualizaciones (RF-032 estadísticas)';

COMMENT ON COLUMN public.ofertas.total_saves IS 
  'Contador de veces que se guardó como cupón';

COMMENT ON COLUMN public.ofertas.total_redeems IS 
  'Contador de canjes exitosos';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ofertas_comercio ON public.ofertas(comercio);
CREATE INDEX IF NOT EXISTS idx_ofertas_comercio_id ON public.ofertas(comercio_id);
CREATE INDEX IF NOT EXISTS idx_ofertas_fecha_fin ON public.ofertas(fecha_fin);
CREATE INDEX IF NOT EXISTS idx_ofertas_is_active ON public.ofertas(is_active);
CREATE INDEX IF NOT EXISTS idx_ofertas_created_at ON public.ofertas(created_at DESC);

-- Índice compuesto para ofertas activas
CREATE INDEX IF NOT EXISTS idx_ofertas_active_dates ON public.ofertas(is_active, fecha_inicio, fecha_fin)
  WHERE is_active = true;

-- Índice de texto completo para búsqueda
CREATE INDEX IF NOT EXISTS idx_ofertas_titulo_trgm ON public.ofertas USING GIN (titulo gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ofertas_descripcion_trgm ON public.ofertas USING GIN (descripcion gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_ofertas_updated_at ON public.ofertas;
CREATE TRIGGER update_ofertas_updated_at
  BEFORE UPDATE ON public.ofertas
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: Incrementar contador de visualizaciones
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION increment_oferta_views()
RETURNS TRIGGER AS $$
BEGIN
  -- Este trigger se llamará desde la aplicación cuando se vea una oferta
  UPDATE public.ofertas
  SET total_views = total_views + 1
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.ofertas ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede ver ofertas activas de comercios aprobados
DROP POLICY IF EXISTS "Ofertas activas son públicas" ON public.ofertas;
CREATE POLICY "Ofertas activas son públicas"
  ON public.ofertas
  FOR SELECT
  USING (
    is_active = true
    AND fecha_inicio <= NOW()
    AND fecha_fin >= NOW()
    AND EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = ofertas.comercio AND is_approved = true
    )
  );

-- Política: Los dueños de comercios pueden ver todas sus ofertas
DROP POLICY IF EXISTS "Dueños pueden ver sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden ver sus ofertas"
  ON public.ofertas
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = ofertas.comercio AND owner_id = auth.uid()
    )
  );

-- Política: Solo dueños de comercios aprobados pueden crear ofertas
DROP POLICY IF EXISTS "Dueños de comercios aprobados pueden crear ofertas" ON public.ofertas;
CREATE POLICY "Dueños de comercios aprobados pueden crear ofertas"
  ON public.ofertas
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = ofertas.comercio 
        AND owner_id = auth.uid()
        AND is_approved = true
    )
  );

-- Política: Los dueños pueden actualizar sus ofertas
DROP POLICY IF EXISTS "Dueños pueden actualizar sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden actualizar sus ofertas"
  ON public.ofertas
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = ofertas.comercio AND owner_id = auth.uid()
    )
  );

-- Política: Los dueños pueden eliminar sus ofertas
DROP POLICY IF EXISTS "Dueños pueden eliminar sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden eliminar sus ofertas"
  ON public.ofertas
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = ofertas.comercio AND owner_id = auth.uid()
    )
  );

-- Política: Admins pueden ver todas las ofertas
DROP POLICY IF EXISTS "Admins pueden ver todas las ofertas" ON public.ofertas;
CREATE POLICY "Admins pueden ver todas las ofertas"
  ON public.ofertas
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
    )
  );

-- -----------------------------------------------------------------------------
-- 7. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Buscar ofertas cercanas (combina con PostGIS de comercios)
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
  image_url TEXT,
  discount_type TEXT,
  discount_value NUMERIC,
  fecha_fin TIMESTAMP WITH TIME ZONE,
  comercio_id UUID,
  comercio_nombre TEXT,
  comercio_direccion TEXT,
  distancia_km NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS oferta_id,
    o.titulo,
    o.descripcion,
    o.image_url,
    o.discount_type,
    o.discount_value,
    o.fecha_fin,
    c.id AS comercio_id,
    c.nombre AS comercio_nombre,
    c.direccion AS comercio_direccion,
    ROUND(
      (ST_Distance(
        c.location,
        ST_MakePoint(user_long, user_lat)::geography
      ) / 1000)::numeric,
      2
    ) AS distancia_km
  FROM public.ofertas o
  JOIN public.comercios c ON o.comercio = c.id
  WHERE 
    c.is_approved = true
    AND o.is_active = true
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION buscar_ofertas_cercanas IS 
  'Busca ofertas activas en un radio desde una ubicación, con filtro opcional por categoría. Ejemplo: SELECT * FROM buscar_ofertas_cercanas(40.4168, -3.7038, 10000, ''Restaurante'', 50);';

-- Función: Incrementar contador de visualizaciones
CREATE OR REPLACE FUNCTION increment_view_count(oferta_id UUID)
RETURNS VOID AS $$
  UPDATE public.ofertas
  SET total_views = total_views + 1
  WHERE id = oferta_id;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

-- Función: Obtener ofertas de un comercio
CREATE OR REPLACE FUNCTION get_ofertas_by_comercio(comercio_id UUID)
RETURNS SETOF public.ofertas AS $$
  SELECT * FROM public.ofertas 
  WHERE comercio = comercio_id
  ORDER BY created_at DESC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Obtener estadísticas de una oferta
CREATE OR REPLACE FUNCTION get_oferta_stats(oferta_id UUID)
RETURNS TABLE (
  total_views INTEGER,
  total_saves INTEGER,
  total_redeems INTEGER,
  conversion_rate NUMERIC
) AS $$
  SELECT 
    o.total_views,
    o.total_saves,
    o.total_redeems,
    CASE 
      WHEN o.total_views > 0 THEN ROUND((o.total_redeems::NUMERIC / o.total_views::NUMERIC * 100), 2)
      ELSE 0
    END AS conversion_rate
  FROM public.ofertas o
  WHERE o.id = oferta_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 8. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT ON public.ofertas TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ofertas TO authenticated;

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'ofertas'
) AS table_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'ofertas';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'ofertas';

-- ==============================================================================
-- MIGRATION (Ejecutar si la tabla ya existe)
-- ==============================================================================
DO $$ 
BEGIN
  -- Renombrar columna user_id a comercio_id si existe
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ofertas' AND column_name = 'user_id') THEN
    ALTER TABLE public.ofertas RENAME COLUMN user_id TO comercio_id;
  END IF;

  -- Actualizar constraint de foreign key
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'ofertas_user_id_fkey') THEN
    ALTER TABLE public.ofertas DROP CONSTRAINT ofertas_user_id_fkey;
    ALTER TABLE public.ofertas ADD CONSTRAINT ofertas_comercio_id_fkey FOREIGN KEY (comercio_id) REFERENCES public.comercios(id) ON DELETE SET NULL;
  END IF;
END $$;
