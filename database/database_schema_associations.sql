-- ==============================================================================
-- ACGeneric - Schema para Gestión de Asociaciones y Grupos
-- ==============================================================================
-- Este script crea las tablas necesarias para soportar:
-- 1. Asociaciones de comerciantes (entidades organizativas)
-- 2. Membresías de comercios en asociaciones (relación N:M)
-- 3. Suscripciones centralizadas
-- 4. Row Level Security (RLS) para control de acceso
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- TABLA: associations
-- Representa una asociación de comerciantes, centro comercial o agrupación
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.associations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Información básica
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    website_url TEXT,
    
    -- Administrador de la asociación
    -- Referencia al usuario que gestiona esta asociación
    admin_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    
    -- Gestión de suscripciones
    subscription_status TEXT CHECK (subscription_status IN ('active', 'inactive', 'trial')) DEFAULT 'inactive',
    subscription_tier TEXT CHECK (subscription_tier IN ('standard', 'premium', 'enterprise')) DEFAULT 'standard',
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    
    -- Configuración de licencias
    max_members INTEGER DEFAULT 10, -- Número máximo de comercios permitidos
    
    -- Metadatos
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices para optimizar búsquedas
CREATE INDEX IF NOT EXISTS idx_associations_admin_user 
    ON public.associations(admin_user_id);

CREATE INDEX IF NOT EXISTS idx_associations_subscription_status 
    ON public.associations(subscription_status);

-- Comentarios
COMMENT ON TABLE public.associations IS 'Asociaciones de comerciantes y entidades organizativas';
COMMENT ON COLUMN public.associations.admin_user_id IS 'Usuario administrador de la asociación';
COMMENT ON COLUMN public.associations.subscription_status IS 'Estado de la suscripción: active, inactive, trial';
COMMENT ON COLUMN public.associations.max_members IS 'Número máximo de comercios permitidos en esta asociación';

-- -----------------------------------------------------------------------------
-- TABLA: association_members
-- Relación N:M entre asociaciones y comercios
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.association_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Relaciones
    association_id UUID REFERENCES public.associations(id) ON DELETE CASCADE NOT NULL,
    business_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE NOT NULL,
    
    -- Estado de la membresía
    status TEXT CHECK (status IN ('invited', 'pending', 'active', 'rejected')) DEFAULT 'invited',
    
    -- Rol del miembro en la asociación
    role TEXT CHECK (role IN ('member', 'admin')) DEFAULT 'member',
    
    -- Fechas
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    joined_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Constraint: Un comercio no puede estar duplicado en la misma asociación
    CONSTRAINT unique_association_business_membership 
        UNIQUE (association_id, business_id)
);

-- Índices para optimizar búsquedas
CREATE INDEX IF NOT EXISTS idx_association_members_association 
    ON public.association_members(association_id);

CREATE INDEX IF NOT EXISTS idx_association_members_business 
    ON public.association_members(business_id);

CREATE INDEX IF NOT EXISTS idx_association_members_status 
    ON public.association_members(status);

-- Comentarios
COMMENT ON TABLE public.association_members IS 'Membresías de comercios en asociaciones';
COMMENT ON COLUMN public.association_members.status IS 'Estado: invited (invitado), pending (solicitó unirse), active (activo), rejected (rechazado)';
COMMENT ON COLUMN public.association_members.role IS 'Rol: member (miembro estándar), admin (sub-administrador)';

-- -----------------------------------------------------------------------------
-- FUNCIÓN: Actualizar updated_at automáticamente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para associations
DROP TRIGGER IF EXISTS update_associations_updated_at ON public.associations;
CREATE TRIGGER update_associations_updated_at
    BEFORE UPDATE ON public.associations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------

-- Habilitar RLS
ALTER TABLE public.associations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.association_members ENABLE ROW LEVEL SECURITY;

-- ===== POLÍTICAS PARA: associations =====

-- 1. Lectura pública: Cualquiera puede ver las asociaciones
DROP POLICY IF EXISTS "Associations are viewable by everyone" ON public.associations;
CREATE POLICY "Associations are viewable by everyone"
    ON public.associations FOR SELECT
    USING (true);

-- 2. Creación: Usuarios autenticados pueden crear asociaciones
DROP POLICY IF EXISTS "Authenticated users can create associations" ON public.associations;
CREATE POLICY "Authenticated users can create associations"
    ON public.associations FOR INSERT
    WITH CHECK (auth.uid() = admin_user_id);

-- 3. Actualización: Solo el administrador puede actualizar
DROP POLICY IF EXISTS "Association admins can update their association" ON public.associations;
CREATE POLICY "Association admins can update their association"
    ON public.associations FOR UPDATE
    USING (auth.uid() = admin_user_id);

-- 4. Eliminación: Solo el administrador puede eliminar
DROP POLICY IF EXISTS "Association admins can delete their association" ON public.associations;
CREATE POLICY "Association admins can delete their association"
    ON public.associations FOR DELETE
    USING (auth.uid() = admin_user_id);

-- ===== POLÍTICAS PARA: association_members =====

-- 1. Lectura: Membresías activas son públicas (para mostrar badges)
DROP POLICY IF EXISTS "Active memberships are public" ON public.association_members;
CREATE POLICY "Active memberships are public"
    ON public.association_members FOR SELECT
    USING (status = 'active');

-- 2. Lectura: Admins y el propio negocio pueden ver todas sus membresías
DROP POLICY IF EXISTS "Admins and members can view their data" ON public.association_members;
CREATE POLICY "Admins and members can view their data"
    ON public.association_members FOR SELECT
    USING (
        -- Usuario es el admin de la asociación
        EXISTS (
            SELECT 1 FROM public.associations 
            WHERE id = association_members.association_id 
            AND admin_user_id = auth.uid()
        )
        OR
        -- Usuario es el comercio miembro
        business_id = auth.uid()
    );

-- 3. Inserción: Solo admins pueden invitar/agregar miembros
DROP POLICY IF EXISTS "Association admins can add members" ON public.association_members;
CREATE POLICY "Association admins can add members"
    ON public.association_members FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.associations 
            WHERE id = association_members.association_id 
            AND admin_user_id = auth.uid()
        )
    );

-- 4. Actualización: Admins pueden gestionar, comercios pueden aceptar invitaciones
DROP POLICY IF EXISTS "Admins can manage members" ON public.association_members;
CREATE POLICY "Admins can manage members"
    ON public.association_members FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.associations 
            WHERE id = association_members.association_id 
            AND admin_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Businesses can accept invitations" ON public.association_members;
CREATE POLICY "Businesses can accept invitations"
    ON public.association_members FOR UPDATE
    USING (business_id = auth.uid())
    WITH CHECK (
        business_id = auth.uid() 
        AND status IN ('invited', 'pending', 'active')
    );

-- 5. Eliminación: Solo admins pueden eliminar membresías
DROP POLICY IF EXISTS "Association admins can remove members" ON public.association_members;
CREATE POLICY "Association admins can remove members"
    ON public.association_members FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.associations 
            WHERE id = association_members.association_id 
            AND admin_user_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- DATOS DE EJEMPLO (Opcional - Comentar si no se desea)
-- -----------------------------------------------------------------------------

-- Insertar una asociación de ejemplo
-- NOTA: Reemplaza 'YOUR-USER-UUID-HERE' con un UUID válido de auth.users
/*
INSERT INTO public.associations (name, description, admin_user_id, subscription_status, subscription_tier, max_members)
VALUES 
    ('Asociación de Comerciantes del Centro', 
     'Agrupación de comercios del centro histórico de la ciudad', 
     'YOUR-USER-UUID-HERE', 
     'active', 
     'premium', 
     50);
*/

-- ==============================================================================
-- FIN DEL SCRIPT
-- ==============================================================================
