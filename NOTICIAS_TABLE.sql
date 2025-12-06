-- Crear la tabla de noticias
-- Primero borramos si existe para asegurar tipos limpios
DROP TABLE IF EXISTS public.noticias CASCADE;

CREATE TABLE public.noticias (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    titulo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    image_url TEXT NOT NULL, -- Mapeo de imageUrl
    url TEXT,               -- Puede ser nulo
    user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid(), -- Para rastrear al propietario
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.noticias ENABLE ROW LEVEL SECURITY;

-- 1. Todo el mundo puede ver las noticias (SELECT)
CREATE POLICY "Las noticias son públicas" 
ON public.noticias FOR SELECT 
USING (true);

-- 2. Todo el mundo (autenticado) puede insertar noticias
CREATE POLICY "Usuarios autenticados pueden crear noticias" 
ON public.noticias FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- 3. Solo los propietarios pueden editar sus noticias (UPDATE)
CREATE POLICY "Usuarios pueden editar sus propias noticias" 
ON public.noticias FOR UPDATE 
USING (auth.uid() = user_id);

-- 4. Solo los propietarios pueden eliminar sus noticias (DELETE)
CREATE POLICY "Usuarios pueden eliminar sus propias noticias" 
ON public.noticias FOR DELETE 
USING (auth.uid() = user_id);

-- DATOS DE PRUEBA
-- Usamos un ID de usuario dummy o NULL si la foreign key lo permite (en este caso user_id es nullable por defecto en definición arriba si no pongo NOT NULL,
-- pero el REFERENCES auth.users podria fallar si el ID no existe en auth.users real).
-- Para evitar errores de FK en pruebas locales sin usuarios reales en auth, insertaremos con user_id NULL o uno simulado si desactivaste la FK.
-- Asumiremos user_id NULL para estos datos semilla públicos.

INSERT INTO public.noticias (titulo, descripcion, image_url, url, user_id)
VALUES 
    (
        'Lanzamiento de la nueva Web', 
        'Estamos emocionados de anunciar el lanzamiento de nuestra nueva plataforma web con tecnologías de vanguardia.', 
        'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&auto=format&fit=crop', 
        'https://ejemplo.com/lanzamiento',
        NULL -- Sin propietario específico (noticia del sistema)
    ),
    (
        'Actualización de Seguridad', 
        'Hemos mejorado nuestros protocolos de seguridad para proteger mejor tus datos.', 
        'https://images.unsplash.com/photo-1555949963-ff9fe0c870eb?w=800&auto=format&fit=crop', 
        NULL, -- Sin URL externa
        NULL
    ),
    (
        'Nuevo servicio disponible', 
        'Ahora puedes acceder a nuestro servicio premium con un 50% de descuento durante el primer mes.', 
        'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=800&auto=format&fit=crop', 
        'https://ejemplo.com/servicios',
        NULL
    );
