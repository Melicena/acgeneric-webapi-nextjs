-- Crear tabla de seguimiento de comercios
CREATE TABLE IF NOT EXISTS public.comercios_seguidos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    comercio_id UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, comercio_id)
);

-- Habilitar RLS
ALTER TABLE public.comercios_seguidos ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad
-- 1. Usuarios pueden ver sus propios seguimientos
CREATE POLICY "Usuarios pueden ver sus propios seguimientos"
ON public.comercios_seguidos FOR SELECT
USING (auth.uid() = user_id);

-- 2. Usuarios pueden crear sus propios seguimientos
CREATE POLICY "Usuarios pueden seguir comercios"
ON public.comercios_seguidos FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 3. Usuarios pueden eliminar sus propios seguimientos
CREATE POLICY "Usuarios pueden dejar de seguir comercios"
ON public.comercios_seguidos FOR DELETE
USING (auth.uid() = user_id);

-- 4. Usuarios pueden actualizar sus preferencias (notificaciones)
CREATE POLICY "Usuarios pueden actualizar sus seguimientos"
ON public.comercios_seguidos FOR UPDATE
USING (auth.uid() = user_id);

-- Índices para rendimiento
CREATE INDEX IF NOT EXISTS idx_comercios_seguidos_user_id ON public.comercios_seguidos(user_id);
CREATE INDEX IF NOT EXISTS idx_comercios_seguidos_comercio_id ON public.comercios_seguidos(comercio_id);
