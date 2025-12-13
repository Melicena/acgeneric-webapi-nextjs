import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * GET /api/usuarios/[id]
 * 
 * Obtiene un usuario por su ID desde la tabla 'usuarios'.
 */
export async function GET(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params

        if (!id) {
            return NextResponse.json({ error: 'ID es requerido' }, { status: 400 })
        }

        console.log(`[API] Buscando usuario con ID: ${id}`)

        // 1. Intentar obtener el usuario de la tabla pública
        const { data: usuarioExistente, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('id', id)
            .single()

        if (error) {
            if (error.code === 'PGRST116') {
                return NextResponse.json({ error: 'Usuario no encontrado' }, { status: 404 })
            }
            return NextResponse.json(
                { error: error.message || 'Error procesando la solicitud' },
                { status: 500 }
            )
        }

        return NextResponse.json({ data: usuarioExistente })

    } catch (error) {
        console.error('Error al obtener usuario:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * PUT /api/usuarios/[id]
 * Actualiza un usuario
 */
export async function PUT(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params
        const body = await request.json()

        if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

        const { data, error } = await supabase
            .from('usuarios')
            .update({
                email: body.email,
                nombre: body.nombre,
            })
            .eq('id', id)
            .select()
            .single()

        if (error) return NextResponse.json({ error: error.message }, { status: 500 })

        return NextResponse.json({ data })
    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}

/**
 * DELETE /api/usuarios/[id]
 * Elimina un usuario
 */
export async function DELETE(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params

        if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

        const { error } = await supabase.from('usuarios').delete().eq('id', id)

        if (error) return NextResponse.json({ error: error.message }, { status: 500 })

        const prefix = `users/${id}/`
        const { data: files, error: listError } = await supabase.storage
            .from('avatars')
            .list(prefix, { limit: 1000 })
        if (!listError && files && files.length > 0) {
            const paths = files.map(f => `${prefix}${f.name}`)
            await supabase.storage.from('avatars').remove(paths)
        }

        return NextResponse.json({ message: 'Usuario eliminado' })
    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}
