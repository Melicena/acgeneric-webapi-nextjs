-- Crear la tabla de ofertas
DROP TABLE IF EXISTS public.ofertas CASCADE;

CREATE TABLE public.ofertas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    comercio TEXT NOT NULL,         -- Nombre o ID del comercio
    titulo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    image_url TEXT NOT NULL,
    fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
    nivel_requerido TEXT NOT NULL,  -- Ej: 'BRONZE', 'SILVER', 'GOLD'
    user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid(), -- Creador de la oferta
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.ofertas ENABLE ROW LEVEL SECURITY;

-- 1. Todo el mundo puede ver las ofertas (SELECT)
-- Opcional: Podrías filtrar aquí para que solo se vean las vigentes (fecha actual entre inicio y fin)
CREATE POLICY "Las ofertas son públicas" 
ON public.ofertas FOR SELECT 
USING (true);

-- 2. Usuarios autenticados pueden crear ofertas (INSERT)
CREATE POLICY "Usuarios autenticados pueden crear ofertas" 
ON public.ofertas FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- 3. Solo el creador puede editar (UPDATE)
CREATE POLICY "Usuarios pueden editar sus propias ofertas" 
ON public.ofertas FOR UPDATE 
USING (auth.uid() = user_id);

-- 4. Solo el creador puede eliminar (DELETE)
CREATE POLICY "Usuarios pueden eliminar sus propias ofertas" 
ON public.ofertas FOR DELETE 
USING (auth.uid() = user_id);

-- DATOS DE PRUEBA
INSERT INTO public.ofertas (comercio, titulo, descripcion, image_url, fecha_inicio, fecha_fin, nivel_requerido, user_id)
VALUES 
    (
        'Supermercado Central',
        '2x1 en Productos Frescos',
        'Aprovecha esta oferta increíble en toda la sección de verduras y frutas.',
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&auto=format&fit=crop',
        NOW(),
        NOW() + INTERVAL '7 days',
        'BRONZE',
        NULL
    ),
    (
        'Tienda de Deportes Pro',
        'Descuento 30% en Zapatillas',
        'Solo para miembros GOLD, descuento exclusivo en running.',
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800&auto=format&fit=crop',
        NOW(),
        NOW() + INTERVAL '1 month',
        'GOLD',
        NULL
    ),
    (
        'Cafetería Aroma',
        'Café Gratis con tu desayuno',
        'Compra cualquier desayuno y te regalamos el café del día.',
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&auto=format&fit=crop',
        NOW() - INTERVAL '2 days',
        NOW() + INTERVAL '3 days',
        'SILVER',
        NULL
    );
