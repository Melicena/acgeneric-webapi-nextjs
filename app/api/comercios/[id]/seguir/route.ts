import { createClient, createClientWithToken } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * POST /api/comercios/[id]/seguir
 * Permite a un usuario seguir a un comercio.
 */
export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        // Verificar si viene el token en el header Authorization (App Móvil)
        const authHeader = request.headers.get('Authorization')
        let supabase

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split(' ')[1]
            supabase = await createClientWithToken(token)
        } else {
            // Fallback a cookies (Web)
            supabase = await createClient()
        }

        const { id: comercioId } = params

        // Verificar autenticación
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
        }

        // Verificar si ya lo sigue
        const { data: existing } = await supabase
            .from('comercios_seguidos')
            .select('id')
            .eq('user_id', user.id)
            .eq('comercio_id', comercioId)
            .single()

        if (existing) {
            return NextResponse.json({ message: 'Ya sigues a este comercio' }, { status: 200 })
        }

        // Crear seguimiento
        const { error } = await supabase
            .from('comercios_seguidos')
            .insert({
                user_id: user.id,
                comercio_id: comercioId,
                notifications_enabled: true
            })

        if (error) {
            console.error('Error creating follow:', error)
            return NextResponse.json({ error: 'Error al seguir al comercio' }, { status: 500 })
        }

        return NextResponse.json({ message: 'Comercio seguido exitosamente' })
    } catch (error) {
        console.error('Error en POST /seguir:', error)
        return NextResponse.json({ error: 'Error interno del servidor' }, { status: 500 })
    }
}

/**
 * DELETE /api/comercios/[id]/seguir
 * Permite a un usuario dejar de seguir a un comercio.
 */
export async function DELETE(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        // Verificar si viene el token en el header Authorization (App Móvil)
        const authHeader = request.headers.get('Authorization')
        let supabase

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split(' ')[1]
            supabase = await createClientWithToken(token)
        } else {
            // Fallback a cookies (Web)
            supabase = await createClient()
        }

        const { id: comercioId } = params

        // Verificar autenticación
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
        }

        // Eliminar seguimiento
        const { error } = await supabase
            .from('comercios_seguidos')
            .delete()
            .eq('user_id', user.id)
            .eq('comercio_id', comercioId)

        if (error) {
            console.error('Error deleting follow:', error)
            return NextResponse.json({ error: 'Error al dejar de seguir' }, { status: 500 })
        }

        return NextResponse.json({ message: 'Dejaste de seguir al comercio' })
    } catch (error) {
        console.error('Error en DELETE /seguir:', error)
        return NextResponse.json({ error: 'Error interno del servidor' }, { status: 500 })
    }
}
