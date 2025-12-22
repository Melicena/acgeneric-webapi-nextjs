-- ==============================================================================
-- STORAGE POLICIES: COMERCIOS
-- ==============================================================================
-- Configuración de seguridad para el bucket 'comercios' donde se guardan
-- las imágenes de los negocios y ofertas.
-- ==============================================================================

-- 1. Crear el bucket si no existe
-- Nota: Esto suele hacerse desde el dashboard, pero se puede intentar vía SQL
INSERT INTO storage.buckets (id, name, public)
VALUES ('comercios', 'comercios', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Habilitar RLS en objetos de storage (por si acaso no está)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- POLÍTICAS DE SEGURIDAD
-- -----------------------------------------------------------------------------

-- 1. SELECT: Acceso público para ver las imágenes
-- Cualquier usuario (autenticado o anónimo) puede ver las imágenes
DROP POLICY IF EXISTS "Imágenes de comercios son públicas" ON storage.objects;
CREATE POLICY "Imágenes de comercios son públicas"
ON storage.objects FOR SELECT
USING ( bucket_id = 'comercios' );

-- 2. INSERT: Usuarios autenticados pueden subir imágenes
-- Restricción: Solo pueden subir a una carpeta que coincida con su ID de usuario
-- Path esperado: {user_id}/{filename}
DROP POLICY IF EXISTS "Usuarios pueden subir imágenes a su carpeta" ON storage.objects;
CREATE POLICY "Usuarios pueden subir imágenes a su carpeta"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'comercios' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. UPDATE: Usuarios pueden actualizar sus propias imágenes
-- Restricción: Solo en su propia carpeta
DROP POLICY IF EXISTS "Usuarios pueden actualizar sus imágenes" ON storage.objects;
CREATE POLICY "Usuarios pueden actualizar sus imágenes"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'comercios' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'comercios' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. DELETE: Usuarios pueden eliminar sus propias imágenes
-- Restricción: Solo en su propia carpeta
DROP POLICY IF EXISTS "Usuarios pueden eliminar sus imágenes" ON storage.objects;
CREATE POLICY "Usuarios pueden eliminar sus imágenes"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'comercios' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- -----------------------------------------------------------------------------
-- POLÍTICAS PARA ADMINISTRADORES (Opcional)
-- -----------------------------------------------------------------------------
-- Permitir a los admins gestionar cualquier imagen en el bucket 'comercios'

DROP POLICY IF EXISTS "Admins tienen control total sobre comercios" ON storage.objects;
CREATE POLICY "Admins tienen control total sobre comercios"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'comercios' AND
  EXISTS (
    SELECT 1 FROM public.usuarios 
    WHERE id = auth.uid() 
    AND rol IN ('SUPER_ADMIN', 'ASSOC_ADMIN')
  )
);
