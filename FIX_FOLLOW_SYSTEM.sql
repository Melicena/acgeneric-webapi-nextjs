-- 1. Eliminar la tabla si existe (para corregir errores de estructura previa)
DROP TABLE IF EXISTS public.comercios_seguidos;

-- 2. Asegurarnos de que la tabla de comercios existe (estructura mínima requerida para la clave foránea)
-- Si ya existe, este bloque no hará nada.
CREATE TABLE IF NOT EXISTS public.comercios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nombre TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Crear la tabla de seguimiento de comercios
CREATE TABLE public.comercios_seguidos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    comercio_id UUID NOT NULL REFERENCES public.comercios(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, comercio_id)
);

-- 4. Habilitar seguridad (RLS)
ALTER TABLE public.comercios_seguidos ENABLE ROW LEVEL SECURITY;

-- 5. Crear políticas de seguridad
CREATE POLICY "Usuarios pueden ver sus propios seguimientos"
ON public.comercios_seguidos FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Usuarios pueden seguir comercios"
ON public.comercios_seguidos FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios pueden dejar de seguir comercios"
ON public.comercios_seguidos FOR DELETE
USING (auth.uid() = user_id);

CREATE POLICY "Usuarios pueden actualizar sus seguimientos"
ON public.comercios_seguidos FOR UPDATE
USING (auth.uid() = user_id);

-- 6. Crear índices
CREATE INDEX idx_comercios_seguidos_user_id ON public.comercios_seguidos(user_id);
CREATE INDEX idx_comercios_seguidos_comercio_id ON public.comercios_seguidos(comercio_id);
