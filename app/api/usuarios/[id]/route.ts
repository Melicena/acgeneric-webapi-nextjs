import { createClient } from '@/lib/supabase/route'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

/**
 * GET /api/usuarios/[id]
 * 
 * Obtiene un usuario por su ID.
 * LÓGICA DE SINCRONIZACIÓN:
 * 1. Busca en la tabla 'usuarios'.
 * 2. Si no existe, busca en Supabase Auth (requiere Service Role Key).
 * 3. Si existe en Auth, lo crea en la tabla 'usuarios' y lo devuelve.
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

        // 1. Intentar obtener el usuario de la tabla pública
        const { data: usuarioExistente, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('id', id)
            .single()

        // Si existe, devolverlo
        if (usuarioExistente) {
            return NextResponse.json({ data: usuarioExistente })
        }

       

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

        return NextResponse.json({ message: 'Usuario eliminado' })
    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}
