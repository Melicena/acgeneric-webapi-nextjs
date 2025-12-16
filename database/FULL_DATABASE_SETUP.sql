-- ==============================================================================
-- ACGeneric - Base de Datos Completa
-- ==============================================================================
-- Script único para copiar y pegar en Supabase SQL Editor
-- Crea todas las tablas, triggers, funciones y políticas RLS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- EXTENSIONES
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verificar PostGIS
SELECT PostGIS_Version();

-- ==============================================================================
-- FUNCIONES GLOBALES
-- ==============================================================================

-- Función para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- TABLA: usuarios
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  rol TEXT NOT NULL DEFAULT 'CLIENT' CHECK (rol IN ('CLIENT', 'BUSINESS_OWNER', 'ASSOC_ADMIN', 'SUPER_ADMIN')),
  comercios UUID[],
  comercios_subs UUID[],
  managed_associations UUID[],
  ultimo_acceso TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON public.usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON public.usuarios(rol);
CREATE INDEX IF NOT EXISTS idx_usuarios_created_at ON public.usuarios(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_usuarios_comercios ON public.usuarios USING GIN(comercios);
CREATE INDEX IF NOT EXISTS idx_usuarios_comercios_subs ON public.usuarios USING GIN(comercios_subs);
CREATE INDEX IF NOT EXISTS idx_usuarios_managed_associations ON public.usuarios USING GIN(managed_associations);

-- Trigger
DROP TRIGGER IF EXISTS update_usuarios_updated_at ON public.usuarios;
CREATE TRIGGER update_usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios pueden ver su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios pueden ver su propio perfil"
  ON public.usuarios FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Usuarios pueden actualizar su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios pueden actualizar su propio perfil"
  ON public.usuarios FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins pueden ver todos los usuarios" ON public.usuarios;
CREATE POLICY "Admins pueden ver todos los usuarios"
  ON public.usuarios FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'))
  );

DROP POLICY IF EXISTS "Sistema puede insertar usuarios" ON public.usuarios;
CREATE POLICY "Sistema puede insertar usuarios"
  ON public.usuarios FOR INSERT WITH CHECK (true);

-- Funciones helper
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM public.usuarios WHERE id = user_id AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'));
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_business_owner(user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM public.usuarios WHERE id = user_id AND rol = 'BUSINESS_OWNER');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Grants
GRANT SELECT, UPDATE ON public.usuarios TO authenticated;
GRANT INSERT ON public.usuarios TO service_role;

-- ==============================================================================
-- TABLA: comercios
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.comercios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  direccion TEXT NOT NULL,
  telefono TEXT NOT NULL,
  horario TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL,
  latitud DOUBLE PRECISION NOT NULL,
  longitud DOUBLE PRECISION NOT NULL,
  imagen_url TEXT NOT NULL,
  personal TEXT[] DEFAULT '{}',
  categorias TEXT[],
  cif TEXT,
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'trial')),
  is_approved BOOLEAN DEFAULT false,
  owner_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_comercios_location ON public.comercios USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_comercios_owner_id ON public.comercios(owner_id);
CREATE INDEX IF NOT EXISTS idx_comercios_is_approved ON public.comercios(is_approved);
CREATE INDEX IF NOT EXISTS idx_comercios_subscription_status ON public.comercios(subscription_status);
CREATE INDEX IF NOT EXISTS idx_comercios_created_at ON public.comercios(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comercios_categorias ON public.comercios USING GIN(categorias);
CREATE INDEX IF NOT EXISTS idx_comercios_nombre_trgm ON public.comercios USING GIN (nombre gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_comercios_descripcion_trgm ON public.comercios USING GIN (descripcion gin_trgm_ops);

-- Trigger de sincronización location
CREATE OR REPLACE FUNCTION sync_comercio_location()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.latitud IS NOT NULL AND NEW.longitud IS NOT NULL) THEN
    NEW.location = ST_MakePoint(NEW.longitud, NEW.latitud)::geography;
  END IF;
  
  IF (NEW.location IS NOT NULL AND (OLD.location IS NULL OR NEW.location != OLD.location)) THEN
    NEW.latitud = ST_Y(NEW.location::geometry);
    NEW.longitud = ST_X(NEW.location::geometry);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_location_trigger ON public.comercios;
CREATE TRIGGER sync_location_trigger
  BEFORE INSERT OR UPDATE ON public.comercios
  FOR EACH ROW
  EXECUTE FUNCTION sync_comercio_location();

DROP TRIGGER IF EXISTS update_comercios_updated_at ON public.comercios;
CREATE TRIGGER update_comercios_updated_at
  BEFORE UPDATE ON public.comercios
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.comercios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Comercios aprobados son públicos" ON public.comercios;
CREATE POLICY "Comercios aprobados son públicos"
  ON public.comercios FOR SELECT USING (is_approved = true);

DROP POLICY IF EXISTS "Dueños pueden ver sus comercios" ON public.comercios;
CREATE POLICY "Dueños pueden ver sus comercios"
  ON public.comercios FOR SELECT USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Dueños pueden actualizar sus comercios" ON public.comercios;
CREATE POLICY "Dueños pueden actualizar sus comercios"
  ON public.comercios FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Business owners pueden crear comercios" ON public.comercios;
CREATE POLICY "Business owners pueden crear comercios"
  ON public.comercios FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'BUSINESS_OWNER')
  );

DROP POLICY IF EXISTS "Admins pueden ver todos los comercios" ON public.comercios;
CREATE POLICY "Admins pueden ver todos los comercios"
  ON public.comercios FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'))
  );

DROP POLICY IF EXISTS "Admins pueden actualizar comercios" ON public.comercios;
CREATE POLICY "Admins pueden actualizar comercios"
  ON public.comercios FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'))
  );

-- Funciones helper
CREATE OR REPLACE FUNCTION buscar_comercios_cercanos(
  user_lat DOUBLE PRECISION,
  user_long DOUBLE PRECISION,
  radio_metros INTEGER DEFAULT 5000,
  limite INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID, nombre TEXT, direccion TEXT, latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION, categorias TEXT[], distancia_km NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.nombre, c.direccion, c.latitud, c.longitud, c.categorias,
    ROUND((ST_Distance(c.location, ST_MakePoint(user_long, user_lat)::geography) / 1000)::numeric, 2) AS distancia_km
  FROM public.comercios c
  WHERE c.is_approved = true
    AND ST_DWithin(c.location, ST_MakePoint(user_long, user_lat)::geography, radio_metros)
  ORDER BY distancia_km
  LIMIT limite;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grants
GRANT SELECT ON public.comercios TO anon, authenticated;
GRANT INSERT, UPDATE ON public.comercios TO authenticated;

-- ==============================================================================
-- TABLA: ofertas
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.ofertas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comercio UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  image_url TEXT NOT NULL,
  fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
  nivel_requerido TEXT NOT NULL DEFAULT 'FREE' CHECK (nivel_requerido IN ('FREE', 'PREMIUM', 'VIP')),
  discount_type TEXT CHECK (discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT', 'FREE_ITEM', '2X1')),
  discount_value NUMERIC,
  condiciones TEXT,
  total_views INTEGER DEFAULT 0,
  total_saves INTEGER DEFAULT 0,
  total_redeems INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_dates CHECK (fecha_fin > fecha_inicio),
  CONSTRAINT valid_discount CHECK (
    (discount_type IS NULL AND discount_value IS NULL) OR
    (discount_type IS NOT NULL AND discount_value IS NOT NULL AND discount_value > 0)
  )
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_ofertas_comercio ON public.ofertas(comercio);
CREATE INDEX IF NOT EXISTS idx_ofertas_user_id ON public.ofertas(user_id);
CREATE INDEX IF NOT EXISTS idx_ofertas_fecha_fin ON public.ofertas(fecha_fin);
CREATE INDEX IF NOT EXISTS idx_ofertas_is_active ON public.ofertas(is_active);
CREATE INDEX IF NOT EXISTS idx_ofertas_created_at ON public.ofertas(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ofertas_active_dates ON public.ofertas(is_active, fecha_inicio, fecha_fin) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ofertas_titulo_trgm ON public.ofertas USING GIN (titulo gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ofertas_descripcion_trgm ON public.ofertas USING GIN (descripcion gin_trgm_ops);

-- Trigger
DROP TRIGGER IF EXISTS update_ofertas_updated_at ON public.ofertas;
CREATE TRIGGER update_ofertas_updated_at
  BEFORE UPDATE ON public.ofertas
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.ofertas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ofertas activas son públicas" ON public.ofertas;
CREATE POLICY "Ofertas activas son públicas"
  ON public.ofertas FOR SELECT USING (
    is_active = true AND fecha_inicio <= NOW() AND fecha_fin >= NOW()
    AND EXISTS (SELECT 1 FROM public.comercios WHERE id = ofertas.comercio AND is_approved = true)
  );

DROP POLICY IF EXISTS "Dueños pueden ver sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden ver sus ofertas"
  ON public.ofertas FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = ofertas.comercio AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Dueños de comercios aprobados pueden crear ofertas" ON public.ofertas;
CREATE POLICY "Dueños de comercios aprobados pueden crear ofertas"
  ON public.ofertas FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = ofertas.comercio AND owner_id = auth.uid() AND is_approved = true)
  );

DROP POLICY IF EXISTS "Dueños pueden actualizar sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden actualizar sus ofertas"
  ON public.ofertas FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = ofertas.comercio AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Dueños pueden eliminar sus ofertas" ON public.ofertas;
CREATE POLICY "Dueños pueden eliminar sus ofertas"
  ON public.ofertas FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = ofertas.comercio AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Admins pueden ver todas las ofertas" ON public.ofertas;
CREATE POLICY "Admins pueden ver todas las ofertas"
  ON public.ofertas FOR ALL USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'))
  );

-- Funciones helper
CREATE OR REPLACE FUNCTION buscar_ofertas_cercanas(
  user_lat DOUBLE PRECISION,
  user_long DOUBLE PRECISION,
  radio_metros INTEGER DEFAULT 10000,
  categoria_filtro TEXT DEFAULT NULL,
  limite INTEGER DEFAULT 100
)
RETURNS TABLE (
  oferta_id UUID, titulo TEXT, descripcion TEXT, image_url TEXT,
  discount_type TEXT, discount_value NUMERIC, fecha_fin TIMESTAMP WITH TIME ZONE,
  comercio_id UUID, comercio_nombre TEXT, comercio_direccion TEXT, distancia_km NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.titulo, o.descripcion, o.image_url, o.discount_type, o.discount_value, o.fecha_fin,
    c.id, c.nombre, c.direccion,
    ROUND((ST_Distance(c.location, ST_MakePoint(user_long, user_lat)::geography) / 1000)::numeric, 2) AS distancia_km
  FROM public.ofertas o
  JOIN public.comercios c ON o.comercio = c.id
  WHERE c.is_approved = true AND o.is_active = true
    AND o.fecha_inicio <= NOW() AND o.fecha_fin >= NOW()
    AND ST_DWithin(c.location, ST_MakePoint(user_long, user_lat)::geography, radio_metros)
    AND (categoria_filtro IS NULL OR categoria_filtro = ANY(c.categorias))
  ORDER BY distancia_km, o.created_at DESC
  LIMIT limite;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_view_count(oferta_id UUID)
RETURNS VOID AS $$
  UPDATE public.ofertas SET total_views = total_views + 1 WHERE id = oferta_id;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

-- Grants
GRANT SELECT ON public.ofertas TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ofertas TO authenticated;

-- ==============================================================================
-- TABLA: cupones
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.cupones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  oferta_id UUID NOT NULL REFERENCES public.ofertas(id) ON DELETE CASCADE,
  comercio UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  imagen_url TEXT NOT NULL,
  valor NUMERIC NOT NULL,
  discount_type TEXT,
  fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'SAVED' CHECK (status IN ('SAVED', 'REDEEMED', 'EXPIRED', 'CANCELLED')),
  canjeado BOOLEAN DEFAULT false,
  qr_hash TEXT UNIQUE,
  qr_token TEXT,
  qr_token_expires_at TIMESTAMP WITH TIME ZONE,
  redeemed_at TIMESTAMP WITH TIME ZONE,
  redeemed_by UUID REFERENCES public.usuarios(id),
  nivel_requerido TEXT NOT NULL DEFAULT 'FREE',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_cupon_dates CHECK (fecha_fin > fecha_inicio),
  CONSTRAINT valid_status_redeemed CHECK (
    (status = 'REDEEMED' AND canjeado = true AND redeemed_at IS NOT NULL) OR (status != 'REDEEMED')
  )
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_cupones_user_id ON public.cupones(user_id);
CREATE INDEX IF NOT EXISTS idx_cupones_oferta_id ON public.cupones(oferta_id);
CREATE INDEX IF NOT EXISTS idx_cupones_comercio ON public.cupones(comercio);
CREATE INDEX IF NOT EXISTS idx_cupones_status ON public.cupones(status);
CREATE INDEX IF NOT EXISTS idx_cupones_qr_hash ON public.cupones(qr_hash) WHERE qr_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cupones_fecha_fin ON public.cupones(fecha_fin);
CREATE INDEX IF NOT EXISTS idx_cupones_created_at ON public.cupones(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cupones_user_active ON public.cupones(user_id, status, fecha_fin) WHERE status = 'SAVED';

-- Triggers
CREATE OR REPLACE FUNCTION generate_cupon_qr_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.qr_hash = encode(digest(NEW.id::text || NEW.user_id::text || NEW.oferta_id::text || NOW()::text, 'sha256'), 'hex');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS generate_qr_hash_trigger ON public.cupones;
CREATE TRIGGER generate_qr_hash_trigger
  BEFORE INSERT ON public.cupones
  FOR EACH ROW
  EXECUTE FUNCTION generate_cupon_qr_hash();

CREATE OR REPLACE FUNCTION mark_expired_cupones()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.fecha_fin < NOW() AND NEW.status = 'SAVED' THEN
    NEW.status = 'EXPIRED';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_expiration_trigger ON public.cupones;
CREATE TRIGGER check_expiration_trigger
  BEFORE UPDATE ON public.cupones
  FOR EACH ROW
  EXECUTE FUNCTION mark_expired_cupones();

DROP TRIGGER IF EXISTS update_cupones_updated_at ON public.cupones;
CREATE TRIGGER update_cupones_updated_at
  BEFORE UPDATE ON public.cupones
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.cupones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios pueden ver sus cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden ver sus cupones"
  ON public.cupones FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Usuarios pueden crear cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden crear cupones"
  ON public.cupones FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Usuarios pueden actualizar sus cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden actualizar sus cupones"
  ON public.cupones FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Dueños pueden ver cupones de sus ofertas" ON public.cupones;
CREATE POLICY "Dueños pueden ver cupones de sus ofertas"
  ON public.cupones FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = cupones.comercio AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Dueños pueden canjear cupones" ON public.cupones;
CREATE POLICY "Dueños pueden canjear cupones"
  ON public.cupones FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = cupones.comercio AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Admins pueden ver todos los cupones" ON public.cupones;
CREATE POLICY "Admins pueden ver todos los cupones"
  ON public.cupones FOR ALL USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN'))
  );

-- Funciones helper
CREATE OR REPLACE FUNCTION generate_qr_token(cupon_id UUID)
RETURNS TABLE (qr_hash TEXT, qr_token TEXT, expires_at TIMESTAMP WITH TIME ZONE) AS $$
DECLARE
  new_token TEXT;
  expiry TIMESTAMP WITH TIME ZONE;
BEGIN
  new_token := encode(gen_random_bytes(32), 'hex');
  expiry := NOW() + INTERVAL '5 minutes';
  
  UPDATE public.cupones
  SET qr_token = new_token, qr_token_expires_at = expiry, updated_at = NOW()
  WHERE id = cupon_id AND user_id = auth.uid();
  
  RETURN QUERY
  SELECT c.qr_hash, c.qr_token, c.qr_token_expires_at
  FROM public.cupones c WHERE c.id = cupon_id;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION redeem_cupon(hash TEXT, token TEXT, redeemer_id UUID DEFAULT NULL)
RETURNS TABLE (success BOOLEAN, message TEXT, cupon_data JSONB) AS $$
DECLARE
  cupon_record RECORD;
BEGIN
  SELECT * INTO cupon_record FROM public.cupones WHERE qr_hash = hash;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Cupón no encontrado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  IF cupon_record.status = 'REDEEMED' THEN
    RETURN QUERY SELECT false, 'Cupón ya canjeado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  IF cupon_record.fecha_fin < NOW() THEN
    UPDATE public.cupones SET status = 'EXPIRED' WHERE id = cupon_record.id;
    RETURN QUERY SELECT false, 'Cupón expirado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  IF cupon_record.qr_token != token THEN
    RETURN QUERY SELECT false, 'Token inválido'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  IF cupon_record.qr_token_expires_at < NOW() THEN
    RETURN QUERY SELECT false, 'Token expirado. Actualiza el QR.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  UPDATE public.cupones
  SET status = 'REDEEMED', canjeado = true, redeemed_at = NOW(),
      redeemed_by = redeemer_id, qr_token = NULL, updated_at = NOW()
  WHERE id = cupon_record.id;
  
  UPDATE public.ofertas SET total_redeems = total_redeems + 1 WHERE id = cupon_record.oferta_id;
  
  RETURN QUERY SELECT true, 'Cupón canjeado exitosamente'::TEXT,
    jsonb_build_object('cupon_id', cupon_record.id, 'nombre', cupon_record.nombre, 'valor', cupon_record.valor, 'user_id', cupon_record.user_id);
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION expire_old_cupones()
RETURNS INTEGER AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  UPDATE public.cupones SET status = 'EXPIRED' WHERE status = 'SAVED' AND fecha_fin < NOW();
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

-- Grants
GRANT SELECT, INSERT, UPDATE ON public.cupones TO authenticated;

-- ==============================================================================
-- TABLA: associations
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.associations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  website_url TEXT,
  admin_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'trial', 'cancelled')),
  subscription_tier TEXT DEFAULT 'standard' CHECK (subscription_tier IN ('standard', 'premium', 'enterprise')),
  subscription_start_date TIMESTAMP WITH TIME ZONE,
  subscription_end_date TIMESTAMP WITH TIME ZONE,
  max_members INTEGER DEFAULT 10,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_associations_admin_user_id ON public.associations(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_associations_subscription_status ON public.associations(subscription_status);
CREATE INDEX IF NOT EXISTS idx_associations_created_at ON public.associations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_associations_name_trgm ON public.associations USING GIN (name gin_trgm_ops);

-- Triggers
CREATE OR REPLACE FUNCTION set_association_max_members()
RETURNS TRIGGER AS $$
BEGIN
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

DROP TRIGGER IF EXISTS update_associations_updated_at ON public.associations;
CREATE TRIGGER update_associations_updated_at
  BEFORE UPDATE ON public.associations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.associations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins pueden ver sus asociaciones" ON public.associations;
CREATE POLICY "Admins pueden ver sus asociaciones"
  ON public.associations FOR SELECT USING (admin_user_id = auth.uid());

DROP POLICY IF EXISTS "Admins pueden actualizar sus asociaciones" ON public.associations;
CREATE POLICY "Admins pueden actualizar sus asociaciones"
  ON public.associations FOR UPDATE USING (admin_user_id = auth.uid()) WITH CHECK (admin_user_id = auth.uid());

DROP POLICY IF EXISTS "ASSOC_ADMIN pueden crear asociaciones" ON public.associations;
CREATE POLICY "ASSOC_ADMIN pueden crear asociaciones"
  ON public.associations FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol IN ('ASSOC_ADMIN', 'SUPER_ADMIN'))
  );



DROP POLICY IF EXISTS "Super admins pueden ver todas las asociaciones" ON public.associations;
CREATE POLICY "Super admins pueden ver todas las asociaciones"
  ON public.associations FOR ALL USING (
    EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'SUPER_ADMIN')
  );

-- NOTA: Las funciones helper se crean después de association_members (línea ~830)
-- has_active_subscription(), get_association_member_count(), can_add_member()

-- Grants
GRANT SELECT, INSERT, UPDATE ON public.associations TO authenticated;

-- ==============================================================================
-- TABLA: association_members
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.association_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.associations(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'REJECTED', 'SUSPENDED')),
  role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('MEMBER', 'MODERATOR')),
  invited_by UUID REFERENCES public.usuarios(id),
  invitation_token TEXT UNIQUE,
  invitation_expires_at TIMESTAMP WITH TIME ZONE,
  joined_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(business_id, association_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_association_members_association_id ON public.association_members(association_id);
CREATE INDEX IF NOT EXISTS idx_association_members_business_id ON public.association_members(business_id);
CREATE INDEX IF NOT EXISTS idx_association_members_status ON public.association_members(status);
CREATE INDEX IF NOT EXISTS idx_association_members_invitation_token ON public.association_members(invitation_token) WHERE invitation_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_association_members_active ON public.association_members(association_id, status) WHERE status = 'ACTIVE';

-- Triggers
CREATE OR REPLACE FUNCTION set_joined_at()
RETURNS TRIGGER AS $$
BEGIN
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

CREATE OR REPLACE FUNCTION generate_invitation_token()
RETURNS TRIGGER AS $$
BEGIN
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

DROP TRIGGER IF EXISTS update_association_members_updated_at ON public.association_members;
CREATE TRIGGER update_association_members_updated_at
  BEFORE UPDATE ON public.association_members
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.association_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins pueden ver miembros de su asociación" ON public.association_members;
CREATE POLICY "Admins pueden ver miembros de su asociación"
  ON public.association_members FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.associations WHERE id = association_members.association_id AND admin_user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Admins pueden gestionar miembros" ON public.association_members;
CREATE POLICY "Admins pueden gestionar miembros"
  ON public.association_members FOR ALL USING (
    EXISTS (SELECT 1 FROM public.associations WHERE id = association_members.association_id AND admin_user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Dueños pueden ver su membresía" ON public.association_members;
CREATE POLICY "Dueños pueden ver su membresía"
  ON public.association_members FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = association_members.business_id AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Dueños pueden responder invitaciones" ON public.association_members;
CREATE POLICY "Dueños pueden responder invitaciones"
  ON public.association_members FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.comercios WHERE id = association_members.business_id AND owner_id = auth.uid())
    AND status = 'PENDING'
  );

-- Funciones helper
CREATE OR REPLACE FUNCTION invite_business_to_association(
  assoc_id UUID, business_uuid UUID, inviter_id UUID
)
RETURNS TABLE (success BOOLEAN, message TEXT, invitation_token TEXT) AS $$
DECLARE
  new_token TEXT;
BEGIN
  IF NOT can_add_member(assoc_id) THEN
    RETURN QUERY SELECT false, 'Límite de miembros alcanzado'::TEXT, NULL::TEXT;
    RETURN;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM public.association_members
    WHERE association_id = assoc_id AND business_id = business_uuid AND status IN ('PENDING', 'ACTIVE')
  ) THEN
    RETURN QUERY SELECT false, 'El comercio ya está en la asociación'::TEXT, NULL::TEXT;
    RETURN;
  END IF;
  
  INSERT INTO public.association_members (association_id, business_id, status, invited_by)
  VALUES (assoc_id, business_uuid, 'PENDING', inviter_id)
  RETURNING invitation_token INTO new_token;
  
  RETURN QUERY SELECT true, 'Invitación enviada'::TEXT, new_token;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION accept_invitation(token TEXT)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
DECLARE
  member_record RECORD;
BEGIN
  SELECT * INTO member_record FROM public.association_members WHERE invitation_token = token;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Invitación no encontrada'::TEXT;
    RETURN;
  END IF;
  
  IF member_record.invitation_expires_at < NOW() THEN
    RETURN QUERY SELECT false, 'Invitación expirada'::TEXT;
    RETURN;
  END IF;
  
  IF member_record.status != 'PENDING' THEN
    RETURN QUERY SELECT false, 'Invitación ya procesada'::TEXT;
    RETURN;
  END IF;
  
  UPDATE public.association_members
  SET status = 'ACTIVE', invitation_token = NULL, updated_at = NOW()
  WHERE id = member_record.id;
  
  RETURN QUERY SELECT true, 'Invitación aceptada'::TEXT;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

-- Grants
GRANT SELECT, INSERT, UPDATE ON public.association_members TO authenticated;

-- ==============================================================================
-- FUNCIONES HELPER PARA ASSOCIATIONS (requiere association_members)
-- ==============================================================================

-- Función: Verificar si asociación tiene suscripción activa
CREATE OR REPLACE FUNCTION has_active_subscription(association_id UUID)
RETURNS BOOLEAN AS $$
  SELECT subscription_status = 'active' AND (subscription_end_date IS NULL OR subscription_end_date >= NOW())
  FROM public.associations WHERE id = association_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Obtener número de miembros activos
CREATE OR REPLACE FUNCTION get_association_member_count(association_id UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER FROM public.association_members
  WHERE association_id = association_id AND status = 'ACTIVE';
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Verificar si puede añadir más miembros
CREATE OR REPLACE FUNCTION can_add_member(association_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  max_allowed INTEGER;
BEGIN
  SELECT get_association_member_count(association_id), max_members
  INTO current_count, max_allowed
  FROM public.associations WHERE id = association_id;
  
  RETURN current_count < max_allowed;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ==============================================================================
-- POLÍTICA ADICIONAL PARA ASSOCIATIONS (requiere association_members)
-- ==============================================================================

-- Ahora que association_members existe, podemos crear esta política
DROP POLICY IF EXISTS "Miembros pueden ver su asociación" ON public.associations;
CREATE POLICY "Miembros pueden ver su asociación"
  ON public.associations FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.association_members am
      JOIN public.comercios c ON am.business_id = c.id
      WHERE am.association_id = associations.id 
        AND c.owner_id = auth.uid() 
        AND am.status = 'ACTIVE'
    )
  );

-- ==============================================================================
-- TRIGGER: handle_new_user (Sincronización con auth.users)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, display_name, avatar_url, rol, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url',
    COALESCE(NEW.raw_user_meta_data->>'rol', 'CLIENT'),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- VERIFICACIÓN FINAL
-- ==============================================================================

DO $$
DECLARE
  tables_expected TEXT[] := ARRAY['usuarios', 'comercios', 'ofertas', 'cupones', 'associations', 'association_members'];
  tbl_name TEXT;
  table_exists BOOLEAN;
  all_exist BOOLEAN := true;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Verificando instalación...';
  RAISE NOTICE '========================================';
  
  FOREACH tbl_name IN ARRAY tables_expected
  LOOP
    SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = tbl_name
    ) INTO table_exists;
    
    IF table_exists THEN
      RAISE NOTICE '  ✓ Tabla: %', tbl_name;
    ELSE
      RAISE WARNING '  ✗ Tabla NO ENCONTRADA: %', tbl_name;
      all_exist := false;
    END IF;
  END LOOP;
  
  IF all_exist THEN
    RAISE NOTICE '';
    RAISE NOTICE '✓ ¡Base de datos creada exitosamente!';
    RAISE NOTICE '';
    RAISE NOTICE 'Próximos pasos:';
    RAISE NOTICE '1. Verificar que PostGIS está habilitado';
    RAISE NOTICE '2. Probar registro de usuario con Supabase Auth';
    RAISE NOTICE '3. Insertar comercios de prueba';
    RAISE NOTICE '4. Probar búsquedas geoespaciales';
  ELSE
    RAISE WARNING '';
    RAISE WARNING '✗ Algunas tablas no se crearon correctamente';
  END IF;
END $$;

-- Verificar PostGIS
SELECT 'PostGIS Version: ' || PostGIS_Version() AS info;

-- Contar políticas RLS
SELECT 'Total políticas RLS: ' || COUNT(*)::TEXT AS info
FROM pg_policies WHERE schemaname = 'public';

-- Contar triggers
SELECT 'Total triggers: ' || COUNT(*)::TEXT AS info
FROM pg_trigger
WHERE tgname NOT LIKE 'RI_%' AND tgrelid::regclass::text LIKE 'public.%';

-- ==============================================================================
-- DATOS DE EJEMPLO (Sample Data)
-- ==============================================================================
-- Datos de prueba para Madrid, España
-- IMPORTANTE: Estos datos se insertan sin RLS (como service_role)
-- Para testing de endpoints y desarrollo
-- ==============================================================================

-- Nota: Los usuarios se crean automáticamente al registrarse con Supabase Auth
-- Aquí solo insertamos comercios, ofertas y cupones de ejemplo

-- -----------------------------------------------------------------------------
-- COMERCIOS DE EJEMPLO EN MADRID
-- -----------------------------------------------------------------------------

-- Insertar comercios (estos se pueden ver públicamente si is_approved = true)
INSERT INTO public.comercios (
  nombre, descripcion, direccion, telefono, horario,
  latitud, longitud, imagen_url, categorias, is_approved, cif
) VALUES 
  -- Zona Centro - Puerta del Sol
  (
    'Restaurante La Puerta',
    'Cocina mediterránea tradicional en el corazón de Madrid. Especialidad en paellas y tapas.',
    'Puerta del Sol, 8, 28013 Madrid',
    '+34 911 234 567',
    'Lunes a Domingo: 12:00-00:00',
    40.4168,
    -3.7038,
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
    ARRAY['Restaurante', 'Mediterránea', 'Tapas'],
    true,
    'B12345678'
  ),
  
  -- Zona Retiro
  (
    'Cafetería El Retiro',
    'Café artesanal y repostería casera. Terraza con vistas al parque.',
    'Calle Alfonso XII, 28, 28014 Madrid',
    '+34 912 345 678',
    'Lunes a Domingo: 08:00-21:00',
    40.4153,
    -3.6844,
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
    ARRAY['Cafetería', 'Repostería', 'Desayunos'],
    true,
    'B23456789'
  ),
  
  -- Gran Vía
  (
    'Moda Gran Vía',
    'Tienda de moda urbana y complementos. Las últimas tendencias al mejor precio.',
    'Gran Vía, 25, 28013 Madrid',
    '+34 913 456 789',
    'Lunes a Sábado: 10:00-21:00, Domingo: 12:00-20:00',
    40.4200,
    -3.7050,
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800',
    ARRAY['Moda', 'Complementos', 'Ropa'],
    true,
    'B34567890'
  ),
  
  -- Malasaña
  (
    'Pizzería Bella Napoli',
    'Auténtica pizza napolitana con horno de leña. Ingredientes importados de Italia.',
    'Calle Fuencarral, 45, 28004 Madrid',
    '+34 914 567 890',
    'Martes a Domingo: 13:00-16:00, 20:00-00:00',
    40.4250,
    -3.7025,
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800',
    ARRAY['Restaurante', 'Italiana', 'Pizza'],
    true,
    'B45678901'
  ),
  
  -- Chueca
  (
    'Gimnasio FitLife',
    'Centro deportivo completo. Clases dirigidas, piscina y spa.',
    'Calle Hortaleza, 88, 28004 Madrid',
    '+34 915 678 901',
    'Lunes a Viernes: 07:00-23:00, Sábado y Domingo: 09:00-21:00',
    40.4260,
    -3.6950,
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800',
    ARRAY['Gimnasio', 'Deporte', 'Wellness'],
    true,
    'B56789012'
  ),
  
  -- Salamanca
  (
    'Librería Cervantes',
    'Librería especializada en literatura española y clásicos. Sección infantil.',
    'Calle Serrano, 52, 28001 Madrid',
    '+34 916 789 012',
    'Lunes a Sábado: 10:00-20:30',
    40.4280,
    -3.6850,
    'https://images.unsplash.com/photo-1507842217343-583bb7270b66?w=800',
    ARRAY['Librería', 'Cultura', 'Educación'],
    true,
    'B67890123'
  ),
  
  -- Chamberí
  (
    'Peluquería Estilo',
    'Salón de belleza y peluquería. Tratamientos capilares y estética.',
    'Calle Bravo Murillo, 15, 28015 Madrid',
    '+34 917 890 123',
    'Martes a Sábado: 10:00-20:00',
    40.4320,
    -3.7080,
    'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=800',
    ARRAY['Peluquería', 'Belleza', 'Estética'],
    true,
    'B78901234'
  ),
  
  -- Lavapiés
  (
    'Bar Tapas del Sur',
    'Tapas andaluzas y vinos de Jerez. Ambiente acogedor y familiar.',
    'Calle Argumosa, 12, 28012 Madrid',
    '+34 918 901 234',
    'Lunes a Domingo: 12:00-01:00',
    40.4100,
    -3.7010,
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800',
    ARRAY['Bar', 'Tapas', 'Vinos'],
    true,
    'B89012345'
  )
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- OFERTAS DE EJEMPLO
-- -----------------------------------------------------------------------------

-- Obtener IDs de comercios para crear ofertas
DO $$
DECLARE
  comercio_puerta UUID;
  comercio_retiro UUID;
  comercio_moda UUID;
  comercio_pizza UUID;
  comercio_gym UUID;
  comercio_libreria UUID;
  comercio_pelu UUID;
  comercio_tapas UUID;
BEGIN
  -- Obtener IDs de comercios
  SELECT id INTO comercio_puerta FROM public.comercios WHERE nombre = 'Restaurante La Puerta' LIMIT 1;
  SELECT id INTO comercio_retiro FROM public.comercios WHERE nombre = 'Cafetería El Retiro' LIMIT 1;
  SELECT id INTO comercio_moda FROM public.comercios WHERE nombre = 'Moda Gran Vía' LIMIT 1;
  SELECT id INTO comercio_pizza FROM public.comercios WHERE nombre = 'Pizzería Bella Napoli' LIMIT 1;
  SELECT id INTO comercio_gym FROM public.comercios WHERE nombre = 'Gimnasio FitLife' LIMIT 1;
  SELECT id INTO comercio_libreria FROM public.comercios WHERE nombre = 'Librería Cervantes' LIMIT 1;
  SELECT id INTO comercio_pelu FROM public.comercios WHERE nombre = 'Peluquería Estilo' LIMIT 1;
  SELECT id INTO comercio_tapas FROM public.comercios WHERE nombre = 'Bar Tapas del Sur' LIMIT 1;
  
  -- Insertar ofertas
  INSERT INTO public.ofertas (
    comercio, titulo, descripcion, image_url,
    fecha_inicio, fecha_fin, discount_type, discount_value,
    condiciones, is_active
  ) VALUES
    -- Restaurante La Puerta
    (
      comercio_puerta,
      '2x1 en Paellas',
      'Lleva dos paellas al precio de una. Válido de lunes a jueves.',
      'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=800',
      NOW(),
      NOW() + INTERVAL '30 days',
      '2X1',
      1,
      'No acumulable con otras ofertas. Válido para paellas de hasta 25€.',
      true
    ),
    (
      comercio_puerta,
      '20% en Menú del Día',
      'Descuento del 20% en nuestro menú del día. Incluye primero, segundo, postre y bebida.',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      NOW(),
      NOW() + INTERVAL '60 days',
      'PERCENTAGE',
      20,
      'Válido de lunes a viernes de 13:00 a 16:00.',
      true
    ),
    
    -- Cafetería El Retiro
    (
      comercio_retiro,
      'Café + Croissant 3€',
      'Desayuno especial: café y croissant artesanal por solo 3€.',
      'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800',
      NOW(),
      NOW() + INTERVAL '45 days',
      'FIXED_AMOUNT',
      3,
      'Válido hasta las 12:00. Un uso por cliente al día.',
      true
    ),
    
    -- Moda Gran Vía
    (
      comercio_moda,
      '30% en Nueva Colección',
      '¡Descuento del 30% en toda la nueva colección de primavera!',
      'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800',
      NOW(),
      NOW() + INTERVAL '20 days',
      'PERCENTAGE',
      30,
      'No aplicable a artículos ya rebajados.',
      true
    ),
    (
      comercio_moda,
      '50€ de Descuento',
      'Descuento de 50€ en compras superiores a 150€.',
      'https://images.unsplash.com/photo-1445205170230-053b83016050?w=800',
      NOW(),
      NOW() + INTERVAL '15 days',
      'FIXED_AMOUNT',
      50,
      'Compra mínima 150€. No acumulable.',
      true
    ),
    
    -- Pizzería Bella Napoli
    (
      comercio_pizza,
      'Pizza Gratis',
      'Compra una pizza familiar y llévate una margarita gratis.',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      NOW(),
      NOW() + INTERVAL '25 days',
      'FREE_ITEM',
      1,
      'Solo para pizzas familiares. La pizza gratis es margarita clásica.',
      true
    ),
    
    -- Gimnasio FitLife
    (
      comercio_gym,
      'Primer Mes 50% OFF',
      'Descuento del 50% en tu primera mensualidad. ¡Empieza a entrenar!',
      'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=800',
      NOW(),
      NOW() + INTERVAL '90 days',
      'PERCENTAGE',
      50,
      'Solo para nuevos clientes. Matrícula no incluida.',
      true
    ),
    (
      comercio_gym,
      '3 Clases de Yoga Gratis',
      'Prueba nuestras clases de yoga. 3 sesiones completamente gratis.',
      'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800',
      NOW(),
      NOW() + INTERVAL '40 days',
      'FREE_ITEM',
      3,
      'Reserva previa obligatoria. Plazas limitadas.',
      true
    ),
    
    -- Librería Cervantes
    (
      comercio_libreria,
      '15% en Libros Infantiles',
      'Descuento del 15% en toda nuestra sección infantil.',
      'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800',
      NOW(),
      NOW() + INTERVAL '35 days',
      'PERCENTAGE',
      15,
      'Válido para libros de la sección infantil y juvenil.',
      true
    ),
    
    -- Peluquería Estilo
    (
      comercio_pelu,
      'Corte + Peinado 25€',
      'Oferta especial: corte y peinado por solo 25€.',
      'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=800',
      NOW(),
      NOW() + INTERVAL '30 days',
      'FIXED_AMOUNT',
      25,
      'Cita previa. No incluye tratamientos adicionales.',
      true
    ),
    
    -- Bar Tapas del Sur
    (
      comercio_tapas,
      '2x1 en Cervezas',
      'Happy Hour: 2 cervezas al precio de 1 de 18:00 a 20:00.',
      'https://images.unsplash.com/photo-1608270586620-248524c67de9?w=800',
      NOW(),
      NOW() + INTERVAL '60 days',
      '2X1',
      1,
      'Válido de lunes a viernes de 18:00 a 20:00.',
      true
    )
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE '✓ Ofertas de ejemplo insertadas';
END $$;

-- ==============================================================================
-- CONSULTAS DE PRUEBA (Testing Queries)
-- ==============================================================================

-- Verificar comercios insertados
SELECT 
  nombre,
  categorias,
  latitud,
  longitud,
  is_approved
FROM public.comercios
ORDER BY nombre;

-- Verificar ofertas insertadas
SELECT 
  o.titulo,
  c.nombre AS comercio,
  o.discount_type,
  o.discount_value,
  o.fecha_fin,
  o.is_active
FROM public.ofertas o
JOIN public.comercios c ON o.comercio = c.id
ORDER BY c.nombre, o.titulo;

-- ==============================================================================
-- PRUEBAS DE FUNCIONES GEOESPACIALES
-- ==============================================================================

-- Test 1: Buscar comercios cerca de Puerta del Sol (radio 2km)
SELECT 
  '=== COMERCIOS CERCA DE PUERTA DEL SOL (2km) ===' AS test;
  
SELECT * FROM buscar_comercios_cercanos(
  40.4168,  -- Latitud Puerta del Sol
  -3.7038,  -- Longitud Puerta del Sol
  2000,     -- 2km de radio
  10        -- Máximo 10 resultados
);

-- Test 2: Buscar ofertas cerca del Retiro (radio 3km)
SELECT 
  '=== OFERTAS CERCA DEL RETIRO (3km) ===' AS test;

SELECT * FROM buscar_ofertas_cercanas(
  40.4153,  -- Latitud Retiro
  -3.6844,  -- Longitud Retiro
  3000,     -- 3km de radio
  NULL,     -- Todas las categorías
  20        -- Máximo 20 resultados
);

-- Test 3: Buscar solo restaurantes cerca de Gran Vía (radio 1km)
SELECT 
  '=== RESTAURANTES CERCA DE GRAN VÍA (1km) ===' AS test;

SELECT 
  c.nombre,
  c.categorias,
  ROUND(
    (ST_Distance(
      c.location,
      ST_MakePoint(-3.7050, 40.4200)::geography
    ) / 1000)::numeric,
    2
  ) AS distancia_km
FROM public.comercios c
WHERE 
  c.is_approved = true
  AND 'Restaurante' = ANY(c.categorias)
  AND ST_DWithin(
    c.location,
    ST_MakePoint(-3.7050, 40.4200)::geography,
    1000
  )
ORDER BY distancia_km;

-- ==============================================================================
-- INSTRUCCIONES PARA CREAR CUPONES DE PRUEBA
-- ==============================================================================

/*
NOTA: Los cupones requieren un user_id válido de auth.users
Para crear cupones de prueba:

1. Registra un usuario en Supabase Auth
2. Obtén su UUID
3. Ejecuta este código reemplazando 'USER_UUID_AQUI':

DO $$
DECLARE
  test_user_id UUID := 'USER_UUID_AQUI';  -- Reemplazar con UUID real
  oferta_paella UUID;
  oferta_cafe UUID;
  comercio_id UUID;
BEGIN
  -- Obtener IDs de ofertas
  SELECT o.id, o.comercio INTO oferta_paella, comercio_id
  FROM public.ofertas o
  WHERE o.titulo = '2x1 en Paellas'
  LIMIT 1;
  
  SELECT o.id INTO oferta_cafe
  FROM public.ofertas o
  WHERE o.titulo = 'Café + Croissant 3€'
  LIMIT 1;
  
  -- Crear cupones de prueba
  INSERT INTO public.cupones (
    user_id, oferta_id, comercio,
    nombre, descripcion, imagen_url, valor,
    discount_type, fecha_inicio, fecha_fin,
    status, nivel_requerido
  ) VALUES
    (
      test_user_id,
      oferta_paella,
      comercio_id,
      '2x1 en Paellas',
      'Lleva dos paellas al precio de una',
      'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=800',
      0,
      '2X1',
      NOW(),
      NOW() + INTERVAL '30 days',
      'SAVED',
      'FREE'
    );
  
  RAISE NOTICE '✓ Cupones de prueba creados para usuario %', test_user_id;
END $$;

-- Probar generación de QR token
SELECT * FROM generate_qr_token('CUPON_UUID_AQUI');

-- Probar canje de cupón
SELECT * FROM redeem_cupon('QR_HASH_AQUI', 'QR_TOKEN_AQUI', NULL);
*/

-- ==============================================================================
-- RESUMEN DE DATOS INSERTADOS
-- ==============================================================================

DO $$
DECLARE
  total_comercios INTEGER;
  total_ofertas INTEGER;
  total_comercios_aprobados INTEGER;
  total_ofertas_activas INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_comercios FROM public.comercios;
  SELECT COUNT(*) INTO total_ofertas FROM public.ofertas;
  SELECT COUNT(*) INTO total_comercios_aprobados FROM public.comercios WHERE is_approved = true;
  SELECT COUNT(*) INTO total_ofertas_activas FROM public.ofertas WHERE is_active = true;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RESUMEN DE DATOS DE EJEMPLO';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Comercios insertados: %', total_comercios;
  RAISE NOTICE 'Comercios aprobados: %', total_comercios_aprobados;
  RAISE NOTICE 'Ofertas insertadas: %', total_ofertas;
  RAISE NOTICE 'Ofertas activas: %', total_ofertas_activas;
  RAISE NOTICE '';
  RAISE NOTICE '✓ Datos de ejemplo listos para testing';
  RAISE NOTICE '';
  RAISE NOTICE 'Ubicación: Madrid, España';
  RAISE NOTICE 'Coordenadas centro: 40.4168, -3.7038';
  RAISE NOTICE '';
END $$;

-- ==============================================================================
-- ✓ INSTALACIÓN COMPLETADA
-- ==============================================================================
