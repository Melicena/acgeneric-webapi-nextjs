-- ==============================================================================
-- TABLA: associations
-- ==============================================================================
-- Almacena las asociaciones de comercios (RF-060)
-- Permite gestión centralizada de múltiples negocios
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.associations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  website_url TEXT,
  admin_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Suscripción
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'trial', 'cancelled')),
  subscription_tier TEXT DEFAULT 'standard' CHECK (subscription_tier IN ('standard', 'premium', 'enterprise')),
  subscription_start_date TIMESTAMP WITH TIME ZONE,
  subscription_end_date TIMESTAMP WITH TIME ZONE,
  
  -- Límites según tier
  max_members INTEGER DEFAULT 10, -- Máximo de comercios permitidos
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.associations IS 
  'Asociaciones de comercios (RF-060). Permite gestión centralizada y suscripción compartida.';

COMMENT ON COLUMN public.associations.admin_user_id IS 
  'Usuario administrador de la asociación (rol ASSOC_ADMIN)';

COMMENT ON COLUMN public.associations.subscription_tier IS 
  'Nivel de suscripción: standard (10 comercios), premium (50), enterprise (200)';

COMMENT ON COLUMN public.associations.max_members IS 
  'Número máximo de comercios permitidos según el tier';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_associations_admin_user_id ON public.associations(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_associations_subscription_status ON public.associations(subscription_status);
CREATE INDEX IF NOT EXISTS idx_associations_created_at ON public.associations(created_at DESC);

-- Índice de texto completo para búsqueda
CREATE INDEX IF NOT EXISTS idx_associations_name_trgm ON public.associations USING GIN (name gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_associations_updated_at ON public.associations;
CREATE TRIGGER update_associations_updated_at
  BEFORE UPDATE ON public.associations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: Establecer max_members según tier
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_association_max_members()
RETURNS TRIGGER AS $$
BEGIN
  -- Establecer max_members según subscription_tier
  NEW.max_members := CASE NEW.subscription_tier
    WHEN 'standard' THEN 10
    WHEN 'premium' THEN 50
    WHEN 'enterprise' THEN 200
    ELSE 10
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_max_members_trigger ON public.associations;
CREATE TRIGGER set_max_members_trigger
  BEFORE INSERT OR UPDATE OF subscription_tier ON public.associations
  FOR EACH ROW
  EXECUTE FUNCTION set_association_max_members();

-- -----------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.associations ENABLE ROW LEVEL SECURITY;

-- Política: Los admins pueden ver sus asociaciones
DROP POLICY IF EXISTS "Admins pueden ver sus asociaciones" ON public.associations;
CREATE POLICY "Admins pueden ver sus asociaciones"
  ON public.associations
  FOR SELECT
  USING (admin_user_id = auth.uid());

-- Política: Los admins pueden actualizar sus asociaciones
DROP POLICY IF EXISTS "Admins pueden actualizar sus asociaciones" ON public.associations;
CREATE POLICY "Admins pueden actualizar sus asociaciones"
  ON public.associations
  FOR UPDATE
  USING (admin_user_id = auth.uid())
  WITH CHECK (admin_user_id = auth.uid());

-- Política: Usuarios con rol ASSOC_ADMIN pueden crear asociaciones
DROP POLICY IF EXISTS "ASSOC_ADMIN pueden crear asociaciones" ON public.associations;
CREATE POLICY "ASSOC_ADMIN pueden crear asociaciones"
  ON public.associations
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('ASSOC_ADMIN', 'SUPER_ADMIN')
    )
  );

-- Política: Miembros pueden ver la asociación a la que pertenecen
DROP POLICY IF EXISTS "Miembros pueden ver su asociación" ON public.associations;
CREATE POLICY "Miembros pueden ver su asociación"
  ON public.associations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.association_members am
      JOIN public.comercios c ON am.business_id = c.id
      WHERE am.association_id = associations.id
        AND c.owner_id = auth.uid()
        AND am.status = 'ACTIVE'
    )
  );

-- Política: Super admins pueden ver todas las asociaciones
DROP POLICY IF EXISTS "Super admins pueden ver todas las asociaciones" ON public.associations;
CREATE POLICY "Super admins pueden ver todas las asociaciones"
  ON public.associations
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'SUPER_ADMIN'
    )
  );

-- -----------------------------------------------------------------------------
-- 7. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Verificar si asociación tiene suscripción activa
CREATE OR REPLACE FUNCTION has_active_subscription(association_id UUID)
RETURNS BOOLEAN AS $$
  SELECT 
    subscription_status = 'active'
    AND (subscription_end_date IS NULL OR subscription_end_date >= NOW())
  FROM public.associations
  WHERE id = association_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Obtener número de miembros actuales
CREATE OR REPLACE FUNCTION get_association_member_count(association_id UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.association_members
  WHERE association_id = association_id
    AND status = 'ACTIVE';
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Verificar si puede añadir más miembros
CREATE OR REPLACE FUNCTION can_add_member(association_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  max_allowed INTEGER;
BEGIN
  SELECT 
    get_association_member_count(association_id),
    max_members
  INTO current_count, max_allowed
  FROM public.associations
  WHERE id = association_id;
  
  RETURN current_count < max_allowed;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION can_add_member IS 
  'Verifica si la asociación puede añadir más miembros según su tier de suscripción';

-- Función: Obtener asociaciones de un usuario
CREATE OR REPLACE FUNCTION get_user_associations(user_uuid UUID)
RETURNS SETOF public.associations AS $$
  SELECT a.*
  FROM public.associations a
  WHERE a.admin_user_id = user_uuid
  ORDER BY a.created_at DESC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Obtener estadísticas de asociación (RF-063)
CREATE OR REPLACE FUNCTION get_association_stats(association_id UUID)
RETURNS TABLE (
  total_members INTEGER,
  active_members INTEGER,
  pending_members INTEGER,
  total_offers INTEGER,
  total_views INTEGER,
  total_redeems INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(DISTINCT am.id)::INTEGER AS total_members,
    COUNT(DISTINCT am.id) FILTER (WHERE am.status = 'ACTIVE')::INTEGER AS active_members,
    COUNT(DISTINCT am.id) FILTER (WHERE am.status = 'PENDING')::INTEGER AS pending_members,
    COUNT(DISTINCT o.id)::INTEGER AS total_offers,
    COALESCE(SUM(o.total_views), 0)::INTEGER AS total_views,
    COALESCE(SUM(o.total_redeems), 0)::INTEGER AS total_redeems
  FROM public.association_members am
  LEFT JOIN public.ofertas o ON o.comercio = am.business_id
  WHERE am.association_id = get_association_stats.association_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_association_stats IS 
  'Obtiene estadísticas agregadas de una asociación (RF-063)';

-- -----------------------------------------------------------------------------
-- 8. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.associations TO authenticated;
GRANT DELETE ON public.associations TO authenticated; -- Controlado por RLS

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'associations'
) AS table_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'associations';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'associations';
