-- ==============================================================================
-- TABLA: usuarios
-- ==============================================================================
-- Almacena información de usuarios de la aplicación (clientes, negocios, admins)
-- Sincronizada automáticamente con auth.users mediante trigger
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  rol TEXT NOT NULL DEFAULT 'CLIENT' CHECK (rol IN ('CLIENT', 'BUSINESS_OWNER', 'ASSOC_ADMIN', 'SUPER_ADMIN')),
  comercios UUID[], -- Array de IDs de comercios que posee (si es BUSINESS_OWNER)
  comercios_subs UUID[], -- Array de IDs de comercios a los que está suscrito (favoritos)
  managed_associations UUID[], -- Array de IDs de asociaciones que administra (si es ASSOC_ADMIN)
  ultimo_acceso TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.usuarios IS 
  'Usuarios de la aplicación. Sincronizada con auth.users mediante trigger handle_new_user()';

COMMENT ON COLUMN public.usuarios.id IS 
  'UUID del usuario (mismo que auth.users.id)';

COMMENT ON COLUMN public.usuarios.rol IS 
  'Rol del usuario: CLIENT (cliente final), BUSINESS_OWNER (dueño de negocio), ASSOC_ADMIN (admin de asociación), SUPER_ADMIN (admin de plataforma)';

COMMENT ON COLUMN public.usuarios.comercios IS 
  'Array de UUIDs de comercios que posee el usuario (solo para BUSINESS_OWNER)';

COMMENT ON COLUMN public.usuarios.comercios_subs IS 
  'Array de UUIDs de comercios favoritos/suscritos (para clientes)';

COMMENT ON COLUMN public.usuarios.managed_associations IS 
  'Array de UUIDs de asociaciones que administra (solo para ASSOC_ADMIN)';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON public.usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON public.usuarios(rol);
CREATE INDEX IF NOT EXISTS idx_usuarios_created_at ON public.usuarios(created_at DESC);

-- Índices GIN para búsquedas en arrays
CREATE INDEX IF NOT EXISTS idx_usuarios_comercios ON public.usuarios USING GIN(comercios);
CREATE INDEX IF NOT EXISTS idx_usuarios_comercios_subs ON public.usuarios USING GIN(comercios_subs);
CREATE INDEX IF NOT EXISTS idx_usuarios_managed_associations ON public.usuarios USING GIN(managed_associations);

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_usuarios_updated_at ON public.usuarios;
CREATE TRIGGER update_usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden ver su propio perfil
DROP POLICY IF EXISTS "Usuarios pueden ver su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios pueden ver su propio perfil"
  ON public.usuarios
  FOR SELECT
  USING (auth.uid() = id);

-- Política: Los usuarios pueden actualizar su propio perfil
DROP POLICY IF EXISTS "Usuarios pueden actualizar su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios pueden actualizar su propio perfil"
  ON public.usuarios
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Política: Los admins pueden ver todos los usuarios
DROP POLICY IF EXISTS "Admins pueden ver todos los usuarios" ON public.usuarios;
CREATE POLICY "Admins pueden ver todos los usuarios"
  ON public.usuarios
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
    )
  );

-- Política: Solo el sistema puede insertar (mediante trigger)
DROP POLICY IF EXISTS "Sistema puede insertar usuarios" ON public.usuarios;
CREATE POLICY "Sistema puede insertar usuarios"
  ON public.usuarios
  FOR INSERT
  WITH CHECK (true); -- El trigger handle_new_user() se ejecuta con SECURITY DEFINER

-- -----------------------------------------------------------------------------
-- 6. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Obtener usuario por ID
CREATE OR REPLACE FUNCTION get_usuario_by_id(user_id UUID)
RETURNS public.usuarios AS $$
  SELECT * FROM public.usuarios WHERE id = user_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Verificar si usuario es admin
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = user_id AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Verificar si usuario es dueño de negocio
CREATE OR REPLACE FUNCTION is_business_owner(user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = user_id AND rol = 'BUSINESS_OWNER'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT, UPDATE ON public.usuarios TO authenticated;
GRANT INSERT ON public.usuarios TO service_role; -- Solo para trigger

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'usuarios'
) AS table_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'usuarios';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'usuarios';
