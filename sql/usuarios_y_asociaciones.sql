-- ==========================================
-- TABLA: usuarios
-- ==========================================
-- Actualización de la tabla usuarios para incluir los nuevos campos

-- Primero, verificar si la tabla existe y alterarla
ALTER TABLE usuarios
ADD COLUMN IF NOT EXISTS token TEXT,
ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMP WITH TIME ZONE;

-- Asegurar que los campos existentes tengan los tipos correctos
-- comercios: array de strings (IDs de comercios)
-- comercios_subs: objeto JSON con estructura { "comercio_id": boolean }

COMMENT ON COLUMN usuarios.comercios IS 'Array de IDs de comercios asociados al usuario';
COMMENT ON COLUMN usuarios.comercios_subs IS 'Objeto JSON con suscripciones a comercios: { "comercio_id": boolean }';
COMMENT ON COLUMN usuarios.token IS 'Token de autenticación del usuario';
COMMENT ON COLUMN usuarios.ultimo_acceso IS 'Fecha y hora del último acceso del usuario';
COMMENT ON COLUMN usuarios.rol IS 'Rol del usuario: usuario, negocio, asociacion_admin';

-- ==========================================
-- TABLA: associations (Asociaciones de Comercios)
-- ==========================================
CREATE TABLE IF NOT EXISTS associations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    logo_url TEXT,
    admin_user_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    comercios_ids TEXT[] NOT NULL DEFAULT '{}',
    activa BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_associations_admin_user_id ON associations(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_associations_activa ON associations(activa);
CREATE INDEX IF NOT EXISTS idx_associations_comercios_ids ON associations USING GIN(comercios_ids);

-- Comentarios
COMMENT ON TABLE associations IS 'Asociaciones de comercios administradas por usuarios';
COMMENT ON COLUMN associations.nombre IS 'Nombre de la asociación';
COMMENT ON COLUMN associations.descripcion IS 'Descripción de la asociación';
COMMENT ON COLUMN associations.logo_url IS 'URL del logo de la asociación';
COMMENT ON COLUMN associations.admin_user_id IS 'ID del usuario administrador de la asociación';
COMMENT ON COLUMN associations.comercios_ids IS 'Array de IDs de comercios que pertenecen a la asociación';
COMMENT ON COLUMN associations.activa IS 'Indica si la asociación está activa';

-- ==========================================
-- TRIGGER: updated_at automático
-- ==========================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_associations_updated_at ON associations;
CREATE TRIGGER update_associations_updated_at
    BEFORE UPDATE ON associations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==========================================
-- ROW LEVEL SECURITY (RLS) - USUARIOS
-- ==========================================

-- Habilitar RLS en usuarios si no está habilitado
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes para recrearlas
DROP POLICY IF EXISTS "Usuarios: lectura pública" ON usuarios;
DROP POLICY IF EXISTS "Usuarios: inserción autenticada" ON usuarios;
DROP POLICY IF EXISTS "Usuarios: actualización propia" ON usuarios;
DROP POLICY IF EXISTS "Usuarios: eliminación propia" ON usuarios;

-- Política: Lectura pública (cualquiera puede leer usuarios)
CREATE POLICY "Usuarios: lectura pública"
    ON usuarios
    FOR SELECT
    USING (true);

-- Política: Inserción solo para usuarios autenticados
CREATE POLICY "Usuarios: inserción autenticada"
    ON usuarios
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Política: Actualización solo del propio usuario
CREATE POLICY "Usuarios: actualización propia"
    ON usuarios
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Política: Eliminación solo del propio usuario
CREATE POLICY "Usuarios: eliminación propia"
    ON usuarios
    FOR DELETE
    USING (auth.uid() = id);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) - ASSOCIATIONS
-- ==========================================

-- Habilitar RLS
ALTER TABLE associations ENABLE ROW LEVEL SECURITY;

-- Política: Lectura pública (cualquiera puede ver asociaciones activas)
CREATE POLICY "Asociaciones: lectura pública de activas"
    ON associations
    FOR SELECT
    USING (activa = true);

-- Política: Lectura completa para administradores de la asociación
CREATE POLICY "Asociaciones: lectura completa para admin"
    ON associations
    FOR SELECT
    USING (auth.uid() = admin_user_id);

-- Política: Inserción solo para usuarios autenticados
CREATE POLICY "Asociaciones: inserción autenticada"
    ON associations
    FOR INSERT
    WITH CHECK (auth.uid() = admin_user_id);

-- Política: Actualización solo por el administrador
CREATE POLICY "Asociaciones: actualización por admin"
    ON associations
    FOR UPDATE
    USING (auth.uid() = admin_user_id)
    WITH CHECK (auth.uid() = admin_user_id);

-- Política: Eliminación solo por el administrador
CREATE POLICY "Asociaciones: eliminación por admin"
    ON associations
    FOR DELETE
    USING (auth.uid() = admin_user_id);

-- ==========================================
-- FUNCIÓN HELPER: Obtener asociaciones administradas por un usuario
-- ==========================================
CREATE OR REPLACE FUNCTION get_user_managed_associations(user_id UUID)
RETURNS TABLE (
    id UUID,
    nombre TEXT,
    descripcion TEXT,
    logo_url TEXT,
    admin_user_id UUID,
    comercios_ids TEXT[],
    activa BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.nombre,
        a.descripcion,
        a.logo_url,
        a.admin_user_id,
        a.comercios_ids,
        a.activa,
        a.created_at,
        a.updated_at
    FROM associations a
    WHERE a.admin_user_id = user_id
    ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- FUNCIÓN HELPER: Verificar si un usuario es admin de asociación
-- ==========================================
CREATE OR REPLACE FUNCTION is_association_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM associations 
        WHERE admin_user_id = user_id 
        AND activa = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- DATOS DE EJEMPLO (Opcional - Comentar si no se necesita)
-- ==========================================

-- Ejemplo de usuario administrador de asociación
-- INSERT INTO usuarios (id, email, display_name, rol, created_at)
-- VALUES 
--     ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'admin@asociacion.com', 'Admin Asociación', 'asociacion_admin', NOW())
-- ON CONFLICT (id) DO NOTHING;

-- Ejemplo de asociación
-- INSERT INTO associations (nombre, descripcion, admin_user_id, comercios_ids, activa)
-- VALUES 
--     ('Asociación de Comerciantes del Centro', 'Agrupación de comercios del centro histórico', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', ARRAY['comercio1', 'comercio2', 'comercio3'], true)
-- ON CONFLICT DO NOTHING;

-- ==========================================
-- VERIFICACIÓN
-- ==========================================

-- Ver estructura de la tabla usuarios
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'usuarios'
-- ORDER BY ordinal_position;

-- Ver estructura de la tabla associations
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'associations'
-- ORDER BY ordinal_position;

-- Ver políticas RLS de usuarios
-- SELECT * FROM pg_policies WHERE tablename = 'usuarios';

-- Ver políticas RLS de associations
-- SELECT * FROM pg_policies WHERE tablename = 'associations';
