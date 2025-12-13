import { createClient, createClientWithToken } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

  let supabase = await createClient()
  let { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    const authHeader = request.headers.get('authorization')
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '')
      supabase = await createClientWithToken(token)
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
  if (!allowed.includes((file as File).type)) {
    return NextResponse.json({ error: 'Tipo no soportado' }, { status: 415 })
  }

  const ext =
    file.type === 'image/png' ? 'png' :
    file.type === 'image/webp' ? 'webp' : 'jpg'

  const path = `users/${id}/avatar-${Date.now()}.${ext}`
  console.log(`[Avatar] Subiendo archivo a: ${path}`)

  // 1. Limpiar avatares antiguos antes de subir el nuevo
  const { data: listData } = await supabase.storage.from('avatars').list(`users/${id}`)
  if (listData && listData.length > 0) {
    const filesToRemove = listData.map(file => `users/${id}/${file.name}`)
    console.log(`[Avatar] Eliminando archivos antiguos:`, filesToRemove)
    await supabase.storage.from('avatars').remove(filesToRemove)
  }

  const { error: uploadError } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true, contentType: file.type, cacheControl: '3600' })

  if (uploadError) {
    console.error('[Avatar] Error subiendo archivo:', uploadError)
    return NextResponse.json({ error: uploadError.message }, { status: 500 })
  }

  const { data: publicUrlData } = supabase.storage.from('avatars').getPublicUrl(path)
  const avatar_url = publicUrlData.publicUrl
  console.log(`[Avatar] URL generada: ${avatar_url}`)

  const { data, error: updateError } = await supabase
    .from('usuarios')
    .update({ avatar_url })
    .eq('id', id)
    .select()
    .single()

  if (updateError) {
    console.error('[Avatar] Error actualizando usuario:', updateError)
    return NextResponse.json({ error: updateError.message }, { status: 500 })
  }

  console.log('[Avatar] Usuario actualizado:', data)
  return NextResponse.json({ data })
}

