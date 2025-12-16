-- ==============================================================================
-- TABLA: association_members
-- ==============================================================================
-- Tabla de relación entre asociaciones y comercios (RF-061)
-- Gestiona membresías, invitaciones y roles
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.association_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.associations(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  
  -- Estado de la membresía
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'REJECTED', 'SUSPENDED')),
  
  -- Rol del miembro en la asociación
  role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('MEMBER', 'MODERATOR')),
  
  -- Invitación
  invited_by UUID REFERENCES public.usuarios(id), -- Quién envió la invitación
  invitation_token TEXT UNIQUE, -- Token para aceptar invitación
  invitation_expires_at TIMESTAMP WITH TIME ZONE, -- Expiración de la invitación
  
  -- Fechas
  joined_at TIMESTAMP WITH TIME ZONE, -- Fecha en que se aceptó la invitación
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraint: Un comercio solo puede estar en una asociación a la vez (opcional)
  UNIQUE(business_id, association_id)
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.association_members IS 
  'Relación entre asociaciones y comercios miembros (RF-061)';

COMMENT ON COLUMN public.association_members.status IS 
  'PENDING (invitación pendiente), ACTIVE (miembro activo), REJECTED (rechazó invitación), SUSPENDED (suspendido)';

COMMENT ON COLUMN public.association_members.role IS 
  'MEMBER (miembro estándar), MODERATOR (puede invitar a otros)';

COMMENT ON COLUMN public.association_members.invitation_token IS 
  'Token único para aceptar invitación mediante link';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_association_members_association_id ON public.association_members(association_id);
CREATE INDEX IF NOT EXISTS idx_association_members_business_id ON public.association_members(business_id);
CREATE INDEX IF NOT EXISTS idx_association_members_status ON public.association_members(status);
CREATE INDEX IF NOT EXISTS idx_association_members_invitation_token ON public.association_members(invitation_token) WHERE invitation_token IS NOT NULL;

-- Índice compuesto para membresías activas
CREATE INDEX IF NOT EXISTS idx_association_members_active ON public.association_members(association_id, status)
  WHERE status = 'ACTIVE';

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_association_members_updated_at ON public.association_members;
CREATE TRIGGER update_association_members_updated_at
  BEFORE UPDATE ON public.association_members
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: Establecer joined_at al activar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_joined_at()
RETURNS TRIGGER AS $$
BEGIN
  -- Establecer joined_at cuando status cambia a ACTIVE
  IF NEW.status = 'ACTIVE' AND (OLD.status IS NULL OR OLD.status != 'ACTIVE') THEN
    NEW.joined_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_joined_at_trigger ON public.association_members;
CREATE TRIGGER set_joined_at_trigger
  BEFORE INSERT OR UPDATE OF status ON public.association_members
  FOR EACH ROW
  EXECUTE FUNCTION set_joined_at();

-- -----------------------------------------------------------------------------
-- 6. TRIGGER: Generar token de invitación
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_invitation_token()
RETURNS TRIGGER AS $$
BEGIN
  -- Generar token único para invitaciones pendientes
  IF NEW.status = 'PENDING' AND NEW.invitation_token IS NULL THEN
    NEW.invitation_token = encode(gen_random_bytes(32), 'hex');
    NEW.invitation_expires_at = NOW() + INTERVAL '7 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS generate_invitation_token_trigger ON public.association_members;
CREATE TRIGGER generate_invitation_token_trigger
  BEFORE INSERT ON public.association_members
  FOR EACH ROW
  EXECUTE FUNCTION generate_invitation_token();

-- -----------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.association_members ENABLE ROW LEVEL SECURITY;

-- Política: Admins de asociación pueden ver sus miembros
DROP POLICY IF EXISTS "Admins pueden ver miembros de su asociación" ON public.association_members;
CREATE POLICY "Admins pueden ver miembros de su asociación"
  ON public.association_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.associations
      WHERE id = association_members.association_id
        AND admin_user_id = auth.uid()
    )
  );

-- Política: Admins pueden gestionar miembros
DROP POLICY IF EXISTS "Admins pueden gestionar miembros" ON public.association_members;
CREATE POLICY "Admins pueden gestionar miembros"
  ON public.association_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.associations
      WHERE id = association_members.association_id
        AND admin_user_id = auth.uid()
    )
  );

-- Política: Dueños de comercios pueden ver su membresía
DROP POLICY IF EXISTS "Dueños pueden ver su membresía" ON public.association_members;
CREATE POLICY "Dueños pueden ver su membresía"
  ON public.association_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = association_members.business_id
        AND owner_id = auth.uid()
    )
  );

-- Política: Dueños pueden aceptar/rechazar invitaciones
DROP POLICY IF EXISTS "Dueños pueden responder invitaciones" ON public.association_members;
CREATE POLICY "Dueños pueden responder invitaciones"
  ON public.association_members
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = association_members.business_id
        AND owner_id = auth.uid()
    )
    AND status = 'PENDING'
  );

-- Política: Moderadores pueden invitar miembros
DROP POLICY IF EXISTS "Moderadores pueden invitar" ON public.association_members;
CREATE POLICY "Moderadores pueden invitar"
  ON public.association_members
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.association_members am
      JOIN public.associations a ON am.association_id = a.id
      JOIN public.comercios c ON am.business_id = c.id
      WHERE am.association_id = association_members.association_id
        AND c.owner_id = auth.uid()
        AND am.role IN ('MODERATOR')
        AND am.status = 'ACTIVE'
    )
    OR EXISTS (
      SELECT 1 FROM public.associations
      WHERE id = association_members.association_id
        AND admin_user_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 8. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Invitar comercio a asociación (RF-061)
CREATE OR REPLACE FUNCTION invite_business_to_association(
  assoc_id UUID,
  business_uuid UUID,
  inviter_id UUID
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  invitation_token TEXT
) AS $$
DECLARE
  member_count INTEGER;
  max_allowed INTEGER;
  new_token TEXT;
BEGIN
  -- Verificar que la asociación puede añadir más miembros
  IF NOT can_add_member(assoc_id) THEN
    RETURN QUERY SELECT false, 'Límite de miembros alcanzado'::TEXT, NULL::TEXT;
    RETURN;
  END IF;
  
  -- Verificar que el comercio no está ya en la asociación
  IF EXISTS (
    SELECT 1 FROM public.association_members
    WHERE association_id = assoc_id
      AND business_id = business_uuid
      AND status IN ('PENDING', 'ACTIVE')
  ) THEN
    RETURN QUERY SELECT false, 'El comercio ya está en la asociación'::TEXT, NULL::TEXT;
    RETURN;
  END IF;
  
  -- Crear invitación
  INSERT INTO public.association_members (
    association_id,
    business_id,
    status,
    invited_by
  ) VALUES (
    assoc_id,
    business_uuid,
    'PENDING',
    inviter_id
  )
  RETURNING invitation_token INTO new_token;
  
  RETURN QUERY SELECT true, 'Invitación enviada'::TEXT, new_token;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION invite_business_to_association IS 
  'Invita un comercio a una asociación. Verifica límites y genera token de invitación.';

-- Función: Aceptar invitación
CREATE OR REPLACE FUNCTION accept_invitation(token TEXT)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  member_record RECORD;
BEGIN
  -- Buscar invitación por token
  SELECT * INTO member_record
  FROM public.association_members
  WHERE invitation_token = token;
  
  -- Verificar que existe
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Invitación no encontrada'::TEXT;
    RETURN;
  END IF;
  
  -- Verificar que no ha expirado
  IF member_record.invitation_expires_at < NOW() THEN
    RETURN QUERY SELECT false, 'Invitación expirada'::TEXT;
    RETURN;
  END IF;
  
  -- Verificar que está pendiente
  IF member_record.status != 'PENDING' THEN
    RETURN QUERY SELECT false, 'Invitación ya procesada'::TEXT;
    RETURN;
  END IF;
  
  -- Aceptar invitación
  UPDATE public.association_members
  SET 
    status = 'ACTIVE',
    invitation_token = NULL,
    updated_at = NOW()
  WHERE id = member_record.id;
  
  RETURN QUERY SELECT true, 'Invitación aceptada'::TEXT;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

-- Función: Rechazar invitación
CREATE OR REPLACE FUNCTION reject_invitation(token TEXT)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
BEGIN
  UPDATE public.association_members
  SET 
    status = 'REJECTED',
    invitation_token = NULL,
    updated_at = NOW()
  WHERE invitation_token = token
    AND status = 'PENDING';
  
  IF FOUND THEN
    RETURN QUERY SELECT true, 'Invitación rechazada'::TEXT;
  ELSE
    RETURN QUERY SELECT false, 'Invitación no encontrada'::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

-- Función: Obtener miembros de una asociación
CREATE OR REPLACE FUNCTION get_association_members(
  assoc_id UUID,
  filter_status TEXT DEFAULT NULL
)
RETURNS TABLE (
  member_id UUID,
  business_id UUID,
  business_name TEXT,
  status TEXT,
  role TEXT,
  joined_at TIMESTAMP WITH TIME ZONE
) AS $$
  SELECT 
    am.id AS member_id,
    c.id AS business_id,
    c.nombre AS business_name,
    am.status,
    am.role,
    am.joined_at
  FROM public.association_members am
  JOIN public.comercios c ON am.business_id = c.id
  WHERE am.association_id = assoc_id
    AND (filter_status IS NULL OR am.status = filter_status)
  ORDER BY am.joined_at DESC NULLS LAST;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 9. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.association_members TO authenticated;
GRANT DELETE ON public.association_members TO authenticated; -- Controlado por RLS

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'association_members'
) AS table_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'association_members';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'association_members';
