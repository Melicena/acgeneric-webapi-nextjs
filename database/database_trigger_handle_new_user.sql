-- ==============================================================================
-- ACGeneric - Trigger para Creación Automática de Usuarios
-- ==============================================================================
-- Este script crea un trigger que automáticamente crea un registro en la tabla
-- public.usuarios cada vez que se crea un nuevo usuario en auth.users
-- 
-- Funciona tanto para registro con email/password como con OAuth (Google, Facebook)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- FUNCIÓN: handle_new_user()
-- Se ejecuta automáticamente cuando se crea un nuevo usuario en auth.users
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insertar nuevo registro en public.usuarios
  INSERT INTO public.usuarios (
    id,
    email,
    display_name,
    avatar_url,
    rol,
    created_at
  )
  VALUES (
    NEW.id,                                                                    -- UUID del usuario de Supabase Auth
    NEW.email,                                                                 -- Email del usuario
    COALESCE(                                                                  -- Nombre: prioridad a metadata de OAuth
      NEW.raw_user_meta_data->>'display_name',                               -- Google/Facebook display_name
      NEW.raw_user_meta_data->>'full_name',                                  -- Google full_name
      split_part(NEW.email, '@', 1)                                           -- Fallback: parte local del email
    ),
    NEW.raw_user_meta_data->>'avatar_url',                                   -- URL de foto de perfil (OAuth)
    COALESCE(NEW.raw_user_meta_data->>'rol', 'CLIENT'),                      -- Rol por defecto: CLIENT
    NOW()                                                                      -- Timestamp de creación
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- TRIGGER: on_auth_user_created
-- Se activa DESPUÉS de cada INSERT en auth.users
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON FUNCTION public.handle_new_user() IS 
  'Crea automáticamente un registro en public.usuarios cuando se registra un nuevo usuario en auth.users. Extrae datos de OAuth si están disponibles.';

COMMENT ON TRIGGER on_auth_user_created ON auth.users IS 
  'Trigger que ejecuta handle_new_user() después de cada registro de usuario';

-- ==============================================================================
-- NOTAS DE IMPLEMENTACIÓN
-- ==============================================================================
-- 
-- 1. METADATA DE OAUTH:
--    - Google proporciona: display_name, full_name, avatar_url, email
--    - Facebook proporciona: full_name, avatar_url, email
--    - La función extrae automáticamente estos datos de raw_user_meta_data
--
-- 2. ROL POR DEFECTO:
--    - Todos los usuarios nuevos se crean con rol 'CLIENT'
--    - Para crear usuarios con rol diferente (BUSINESS_OWNER, ASSOC_ADMIN):
--      * Incluir 'rol' en metadata durante signUp:
--        supabase.auth.signUp({
--          email, 
--          password, 
--          options: { data: { rol: 'BUSINESS_OWNER' } }
--        })
--
-- 3. SINCRONIZACIÓN:
--    - El trigger garantiza que cada usuario en auth.users tenga un registro en usuarios
--    - Si falla la inserción, el registro en auth.users se revierte (transacción)
--
-- 4. SEGURIDAD:
--    - SECURITY DEFINER: La función se ejecuta con permisos del creador
--    - Esto permite insertar en public.usuarios incluso si el usuario no tiene permisos directos
--
-- ==============================================================================
-- TESTING
-- ==============================================================================
--
-- Para probar el trigger:
--
-- 1. Registro con email/password:
--    En tu app Android:
--    supabase.auth.signUp({
--      email: "test@example.com",
--      password: "password123"
--    })
--
-- 2. Login con Google:
--    supabase.auth.signInWithOAuth({ provider: 'google' })
--
-- 3. Verificar que se creó el usuario:
--    SELECT * FROM public.usuarios WHERE email = 'test@example.com';
--
-- ==============================================================================
