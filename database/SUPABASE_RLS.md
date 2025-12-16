# Configuración de Seguridad Supabase (RLS)

Para que la subida de avatares funcione correctamente (tanto vía API backend como fallback directo), es necesario configurar las políticas de seguridad (RLS) en el bucket `avatars` de Supabase Storage.

## Storage: Bucket `avatars`

Crea un bucket llamado `avatars` y hazlo público. Luego ejecuta el siguiente SQL en el Editor de Supabase:

```sql
-- 1. Permitir acceso público para ver los avatares (SELECT)
-- Necesario para que la app pueda mostrar la imagen usando publicUrl
create policy "Avatar público"
on storage.objects for select
using ( bucket_id = 'avatars' );

-- 2. Permitir a usuarios autenticados subir su propio avatar (INSERT)
-- Restringe la subida a la carpeta que coincide con su UID
create policy "Usuarios pueden subir su avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 3. Permitir a usuarios actualizar su propio avatar (UPDATE)
-- Permite sobrescribir archivos en su propia carpeta
create policy "Usuarios pueden actualizar su avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 4. (Opcional) Permitir borrar su propio avatar
create policy "Usuarios pueden borrar su avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Backend API

Si utilizas el endpoint `POST /api/usuarios/:id/avatar`, asegúrate de que el backend:
1. Verifica el token JWT del usuario.
2. Usa el ID del usuario autenticado para realizar la operación en la base de datos o storage.
3. Si usa Service Role, bypasses RLS, pero debe validar la autorización manualmente.
