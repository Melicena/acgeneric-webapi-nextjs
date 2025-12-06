-- Crear la tabla de cupones
DROP TABLE IF EXISTS public.cupones CASCADE;

CREATE TABLE public.cupones (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nombre TEXT NOT NULL,
    imagen_url TEXT NOT NULL,       -- Mapeo de imagenUrl
    descripcion TEXT NOT NULL,
    puntos_requeridos INTEGER DEFAULT 0 NOT NULL,
    store_id TEXT NOT NULL,         -- Podría ser UUID si reference a una tabla de comercios
    fecha_fin TIMESTAMP WITH TIME ZONE, -- String en modelo, Timestamp en DB es mejor practica
    qr_code TEXT,                   -- Puede ser la data del QR o la URL
    nivel_requerido TEXT,           -- Ej: 'GOLD'
    estado TEXT DEFAULT 'ACTIVO',   -- Ej: 'ACTIVO', 'AGOTADO', 'VENCIDO'
    comercio TEXT NOT NULL,         -- Nombre del comercio
    user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid(), -- Creador del cupón 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.cupones ENABLE ROW LEVEL SECURITY;

-- 1. Todo el mundo puede ver los cupones (SELECT)
CREATE POLICY "Los cupones son públicos" 
ON public.cupones FOR SELECT 
USING (true);

-- 2. Administradores/Comercios autenticados pueden crear (INSERT)
CREATE POLICY "Usuarios autenticados pueden crear cupones" 
ON public.cupones FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- 3. Solo el creador puede editar (UPDATE)
CREATE POLICY "Creadores pueden editar sus cupones" 
ON public.cupones FOR UPDATE 
USING (auth.uid() = user_id);

-- 4. Solo el creador puede eliminar (DELETE)
CREATE POLICY "Creadores pueden eliminar sus cupones" 
ON public.cupones FOR DELETE 
USING (auth.uid() = user_id);

-- DATOS DE PRUEBA
INSERT INTO public.cupones (nombre, imagen_url, descripcion, puntos_requeridos, store_id, fecha_fin, qr_code, nivel_requerido, estado, comercio, user_id)
VALUES 
    (
        'Descuento 5€ en Comida',
        'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=800&auto=format&fit=crop', -- Pizza
        'Válido por compras superiores a 20€ en toda la carta.',
        500,        -- Puntos
        'STORE_001',
        NOW() + INTERVAL '30 days',
        'QR_DATA_123456',
        'BRONZE',
        'ACTIVO',
        'Pizzería Napoli',
        NULL -- Sin user_id para datos semilla
    ),
    (
        'Entrada de Cine Gratis',
        'https://images.unsplash.com/photo-1542204165-65bf26472b9b?w=800&auto=format&fit=crop', -- Cine Popcorn
        'Canjea este cupón por una entrada para cualquier película 2D.',
        1000,       -- Puntos
        'STORE_002',
        NOW() + INTERVAL '15 days',
        'QR_DATA_CINE_FREE',
        'SILVER',
        'ACTIVO',
        'CineStar Central',
        NULL
    ),
    (
        'Pack de Bienvenida VIP',
        'https://images.unsplash.com/photo-1599839575945-a9e5af0c3fa5?w=800&auto=format&fit=crop', -- Gift
        'Pack exclusivo para nuevos miembros GOLD.',
        0,          -- Gratis para el nivel
        'STORE_001',
        NOW() + INTERVAL '60 days',
        'QR_VIP_WELCOME',
        'GOLD',
        'ACTIVO',
        'Club VIP',
        NULL
    );
