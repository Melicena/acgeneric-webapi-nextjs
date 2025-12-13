## Objetivo

* Agregar un endpoint que reciba una imagen, la suba al bucket `avatars` de Supabase Storage y actualice `usuarios.avatar_url` para el `id` indicado.

## Endpoint

* Ruta: `POST /api/usuarios/[id]/avatar`

* Entrada: `multipart/form-data` con campo `file` (PNG, JPEG, WEBP)

* Autenticación: cookies o `Authorization: Bearer <token>`; debe coincidir `user.id === id`

* Respuesta: JSON con `data` del usuario actualizado (incluye `avatar_url`)

## Flujo

* Validar `id` desde `params` y autenticar usando utilidades existentes (`createClient`, `createClientWithToken`).

* Leer `formData()` y obtener `file`.

* Validar tipo MIME permitido.

* Construir `path` determinista: `users/<id>/avatar.<ext>`.

* Subir al bucket `avatars` con `upsert: true` y `contentType`.

* Obtener `publicUrl` con `getPublicUrl(path)`.

* Actualizar `usuarios.avatar_url` donde `id = <id>` y devolver el registro.

## Seguridad y RLS

* Bloquear si no hay usuario autenticado o si `user.id !== id` → `401`.

* Reutilizar el patrón de autenticación de `PUT /api/usuarios` para RLS (cookies y header bearer).

* Bucket `avatars` debe tener lecturas públicas; si es privado, se puede devolver `createSignedUrl(path, ttl)`.

## Implementación

* Archivo: `app/api/usuarios/[id]/avatar/route.ts`

```ts
import { createClient, createClientWithToken } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

  let supabase = await createClient()
  let { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    const authHeader = request.headers.get('authorization')
    if (authHeader) {
      supabase = await createClientWithToken(authHeader.replace('Bearer ', ''))
      const { data: { user: headerUser } } = await supabase.auth.getUser()
      user = headerUser
    }
  }
  if (!user || user.id !== id) {
    return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
  }

  const form = await request.formData()
  const file = form.get('file') as File | null
  if (!file) return NextResponse.json({ error: 'Archivo requerido' }, { status: 400 })
  const allowed = ['image/png', 'image/jpeg', 'image/webp']
  if (!allowed.includes(file.type)) return NextResponse.json({ error: 'Tipo no soportado' }, { status: 415 })

  const ext = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg'
  const path = `users/${id}/avatar.${ext}`

  const { error: uploadError } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true, contentType: file.type, cacheControl: '3600' })
  if (uploadError) return NextResponse.json({ error: uploadError.message }, { status: 500 })

  const { data: publicUrlData } = supabase.storage.from('avatars').getPublicUrl(path)
  const avatar_url = publicUrlData.publicUrl

  const { data, error: updateError } = await supabase
    .from('usuarios')
    .update({ avatar_url })
    .eq('id', id)
    .select()
    .single()
  if (updateError) return NextResponse.json({ error: updateError.message }, { status: 500 })

  return NextResponse.json({ data })
}
```

## Referencias de código

* Cliente para rutas API: `lib/supabase/route.ts:43`

* Autenticación con Bearer y cookies: `app/api/usuarios/route.ts:131`

* Tabla y columnas tipadas: `lib/supabase/database.types.ts:150-190` (`usuarios.avatar_url`)

## Configuración requerida

* Crear bucket `avatars` en Supabase Storage; habilitar lectura pública o ajustar a URL firmada.

* Límite de tamaño (p.ej. 5–10MB) y tipos permitidos (PNG/JPEG/WEBP).

## Ejemplo de uso

* Frontend:

```ts
const formData = new FormData()
formData.append('file', fileInput.files[0])
await fetch(`/api/usuarios/${user.id}/avatar`, { method: 'POST', body: formData })
```

## Opcionales

* Crea las reglas para lectura publica y actualizacion solo dueño imagen. 

- Regenerar URL firmada si el bucket es privado.

- Cuando un usuario seal eliminado de supabase auth, su avatar deve ser eliminado.

