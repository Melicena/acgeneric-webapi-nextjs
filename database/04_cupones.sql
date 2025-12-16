-- ==============================================================================
-- TABLA: cupones
-- ==============================================================================
-- Almacena los cupones guardados por usuarios y su estado de canje
-- CORE del sistema - RF-031 (Canjeo de cupones con QR)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- 1. CREAR TABLA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cupones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  oferta_id UUID NOT NULL REFERENCES public.ofertas(id) ON DELETE CASCADE,
  comercio UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
  
  -- Datos del cupón (desnormalizados para histórico)
  nombre TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  imagen_url TEXT NOT NULL,
  valor NUMERIC NOT NULL, -- Valor del descuento
  discount_type TEXT,
  
  -- Fechas de validez
  fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Estado del cupón
  status TEXT NOT NULL DEFAULT 'SAVED' CHECK (status IN ('SAVED', 'REDEEMED', 'EXPIRED', 'CANCELLED')),
  canjeado BOOLEAN DEFAULT false, -- Redundante con status, para compatibilidad
  
  -- Seguridad QR (RF-031)
  qr_hash TEXT UNIQUE, -- Hash único para validación segura del QR
  qr_token TEXT, -- Token temporal para canje (expira en 5 min)
  qr_token_expires_at TIMESTAMP WITH TIME ZONE, -- Expiración del token
  
  -- Auditoría de canje
  redeemed_at TIMESTAMP WITH TIME ZONE, -- Fecha y hora del canje
  redeemed_by UUID REFERENCES public.usuarios(id), -- Empleado que canjeó (opcional)
  
  -- Nivel requerido
  nivel_requerido TEXT NOT NULL DEFAULT 'FREE',
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_cupon_dates CHECK (fecha_fin > fecha_inicio),
  CONSTRAINT valid_status_redeemed CHECK (
    (status = 'REDEEMED' AND canjeado = true AND redeemed_at IS NOT NULL) OR
    (status != 'REDEEMED')
  )
);

-- -----------------------------------------------------------------------------
-- 2. COMENTARIOS
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.cupones IS 
  'Cupones guardados por usuarios. CORE del sistema (RF-031 canjeo con QR)';

COMMENT ON COLUMN public.cupones.qr_hash IS 
  'Hash único y permanente del cupón para identificación en QR';

COMMENT ON COLUMN public.cupones.qr_token IS 
  'Token temporal (5 min) para validación segura del canje. Se regenera cada vez que se muestra el QR.';

COMMENT ON COLUMN public.cupones.status IS 
  'SAVED (guardado), REDEEMED (canjeado), EXPIRED (expirado), CANCELLED (cancelado)';

COMMENT ON COLUMN public.cupones.redeemed_by IS 
  'ID del empleado del comercio que escaneó y validó el cupón';

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_cupones_user_id ON public.cupones(user_id);
CREATE INDEX IF NOT EXISTS idx_cupones_oferta_id ON public.cupones(oferta_id);
CREATE INDEX IF NOT EXISTS idx_cupones_comercio ON public.cupones(comercio);
CREATE INDEX IF NOT EXISTS idx_cupones_status ON public.cupones(status);
CREATE INDEX IF NOT EXISTS idx_cupones_qr_hash ON public.cupones(qr_hash) WHERE qr_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cupones_fecha_fin ON public.cupones(fecha_fin);
CREATE INDEX IF NOT EXISTS idx_cupones_created_at ON public.cupones(created_at DESC);

-- Índice compuesto para cupones activos de un usuario
CREATE INDEX IF NOT EXISTS idx_cupones_user_active ON public.cupones(user_id, status, fecha_fin)
  WHERE status = 'SAVED';

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: Actualizar updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_cupones_updated_at ON public.cupones;
CREATE TRIGGER update_cupones_updated_at
  BEFORE UPDATE ON public.cupones
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. TRIGGER: Generar QR hash al crear cupón
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_cupon_qr_hash()
RETURNS TRIGGER AS $$
BEGIN
  -- Generar hash único para el QR (permanente)
  NEW.qr_hash = encode(
    digest(
      NEW.id::text || NEW.user_id::text || NEW.oferta_id::text || NOW()::text,
      'sha256'
    ),
    'hex'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS generate_qr_hash_trigger ON public.cupones;
CREATE TRIGGER generate_qr_hash_trigger
  BEFORE INSERT ON public.cupones
  FOR EACH ROW
  EXECUTE FUNCTION generate_cupon_qr_hash();

-- -----------------------------------------------------------------------------
-- 6. TRIGGER: Marcar cupones expirados automáticamente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_expired_cupones()
RETURNS TRIGGER AS $$
BEGIN
  -- Marcar como expirado si la fecha_fin ha pasado
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

-- -----------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.cupones ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios solo pueden ver sus propios cupones
DROP POLICY IF EXISTS "Usuarios pueden ver sus cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden ver sus cupones"
  ON public.cupones
  FOR SELECT
  USING (user_id = auth.uid());

-- Política: Los usuarios pueden crear cupones (guardar ofertas)
DROP POLICY IF EXISTS "Usuarios pueden crear cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden crear cupones"
  ON public.cupones
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Política: Los usuarios pueden actualizar sus cupones (ej: cancelar)
DROP POLICY IF EXISTS "Usuarios pueden actualizar sus cupones" ON public.cupones;
CREATE POLICY "Usuarios pueden actualizar sus cupones"
  ON public.cupones
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Política: Los dueños de comercios pueden ver cupones de sus ofertas
DROP POLICY IF EXISTS "Dueños pueden ver cupones de sus ofertas" ON public.cupones;
CREATE POLICY "Dueños pueden ver cupones de sus ofertas"
  ON public.cupones
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = cupones.comercio AND owner_id = auth.uid()
    )
  );

-- Política: Los dueños de comercios pueden canjear cupones
DROP POLICY IF EXISTS "Dueños pueden canjear cupones" ON public.cupones;
CREATE POLICY "Dueños pueden canjear cupones"
  ON public.cupones
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.comercios
      WHERE id = cupones.comercio AND owner_id = auth.uid()
    )
  );

-- Política: Admins pueden ver todos los cupones
DROP POLICY IF EXISTS "Admins pueden ver todos los cupones" ON public.cupones;
CREATE POLICY "Admins pueden ver todos los cupones"
  ON public.cupones
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
    )
  );

-- -----------------------------------------------------------------------------
-- 8. FUNCIONES HELPER
-- -----------------------------------------------------------------------------

-- Función: Generar token temporal para QR (RF-031)
CREATE OR REPLACE FUNCTION generate_qr_token(cupon_id UUID)
RETURNS TABLE (
  qr_hash TEXT,
  qr_token TEXT,
  expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  new_token TEXT;
  expiry TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Generar token aleatorio
  new_token := encode(gen_random_bytes(32), 'hex');
  expiry := NOW() + INTERVAL '5 minutes';
  
  -- Actualizar cupón con nuevo token
  UPDATE public.cupones
  SET 
    qr_token = new_token,
    qr_token_expires_at = expiry,
    updated_at = NOW()
  WHERE id = cupon_id AND user_id = auth.uid();
  
  -- Retornar datos para generar QR
  RETURN QUERY
  SELECT 
    c.qr_hash,
    c.qr_token,
    c.qr_token_expires_at
  FROM public.cupones c
  WHERE c.id = cupon_id;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION generate_qr_token IS 
  'Genera un token temporal (5 min) para mostrar QR de canje. Llamar cada vez que el usuario abre el cupón.';

-- Función: Validar y canjear cupón con QR (RF-031)
CREATE OR REPLACE FUNCTION redeem_cupon(
  hash TEXT,
  token TEXT,
  redeemer_id UUID DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  cupon_data JSONB
) AS $$
DECLARE
  cupon_record RECORD;
BEGIN
  -- Buscar cupón por hash
  SELECT * INTO cupon_record
  FROM public.cupones
  WHERE qr_hash = hash;
  
  -- Verificar que existe
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Cupón no encontrado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- Verificar que no está canjeado
  IF cupon_record.status = 'REDEEMED' THEN
    RETURN QUERY SELECT false, 'Cupón ya canjeado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- Verificar que no está expirado
  IF cupon_record.fecha_fin < NOW() THEN
    UPDATE public.cupones SET status = 'EXPIRED' WHERE id = cupon_record.id;
    RETURN QUERY SELECT false, 'Cupón expirado'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- Verificar token temporal
  IF cupon_record.qr_token != token THEN
    RETURN QUERY SELECT false, 'Token inválido'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- Verificar que el token no ha expirado
  IF cupon_record.qr_token_expires_at < NOW() THEN
    RETURN QUERY SELECT false, 'Token expirado. Actualiza el QR.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- TODO: Verificar que el usuario que canjea es del comercio correcto
  
  -- CANJEAR CUPÓN
  UPDATE public.cupones
  SET 
    status = 'REDEEMED',
    canjeado = true,
    redeemed_at = NOW(),
    redeemed_by = redeemer_id,
    qr_token = NULL, -- Invalidar token
    updated_at = NOW()
  WHERE id = cupon_record.id;
  
  -- Incrementar contador de canjes en la oferta
  UPDATE public.ofertas
  SET total_redeems = total_redeems + 1
  WHERE id = cupon_record.oferta_id;
  
  -- Retornar éxito con datos del cupón
  RETURN QUERY SELECT 
    true,
    'Cupón canjeado exitosamente'::TEXT,
    jsonb_build_object(
      'cupon_id', cupon_record.id,
      'nombre', cupon_record.nombre,
      'valor', cupon_record.valor,
      'user_id', cupon_record.user_id
    );
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION redeem_cupon IS 
  'Valida y canjea un cupón mediante QR hash y token temporal. Retorna success, message y datos del cupón.';

-- Función: Obtener cupones de un usuario
CREATE OR REPLACE FUNCTION get_user_cupones(
  user_uuid UUID,
  filter_status TEXT DEFAULT NULL
)
RETURNS SETOF public.cupones AS $$
  SELECT * FROM public.cupones
  WHERE user_id = user_uuid
    AND (filter_status IS NULL OR status = filter_status)
  ORDER BY 
    CASE status
      WHEN 'SAVED' THEN 1
      WHEN 'REDEEMED' THEN 2
      WHEN 'EXPIRED' THEN 3
      ELSE 4
    END,
    fecha_fin ASC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Función: Marcar cupones expirados (para cron job)
CREATE OR REPLACE FUNCTION expire_old_cupones()
RETURNS INTEGER AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  UPDATE public.cupones
  SET status = 'EXPIRED'
  WHERE status = 'SAVED'
    AND fecha_fin < NOW();
  
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION expire_old_cupones IS 
  'Marca cupones guardados como expirados si su fecha_fin ha pasado. Ejecutar en cron job cada hora.';

-- -----------------------------------------------------------------------------
-- 9. GRANTS (Permisos)
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.cupones TO authenticated;
GRANT DELETE ON public.cupones TO authenticated; -- Controlado por RLS

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Verificar que la tabla existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'cupones'
) AS table_exists;

-- Verificar RLS está habilitado
SELECT relrowsecurity FROM pg_class WHERE relname = 'cupones';

-- Listar políticas
SELECT * FROM pg_policies WHERE tablename = 'cupones';

-- Test: Generar token QR (requiere cupón existente)
-- SELECT * FROM generate_qr_token('cupon-uuid-aqui');

-- Test: Validar y canjear cupón (requiere hash y token)
-- SELECT * FROM redeem_cupon('hash-aqui', 'token-aqui', 'redeemer-uuid');
