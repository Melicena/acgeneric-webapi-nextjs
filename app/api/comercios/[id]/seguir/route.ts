import { createClient, createClientWithToken } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * POST /api/comercios/[id]/seguir
 * Permite a un usuario seguir a un comercio.
 */
export async function POST(
    request: Request,
    context: { params: Promise<{ id: string }> } // Cambio aquí: params es una Promesa en Next.js App Router (a veces)
) {
    try {
        // En Next.js App Router reciente, params puede necesitar await si se trata como objeto dinámico, 
        // pero la firma estándar es { params }: { params: { id: string } }.
        // Sin embargo, si params llega vacío o undefined, comercioId será undefined.
        
        // Corrección de seguridad: asegurarnos de leer params correctamente
        const { id } = await context.params
        const comercioId = id
        
        if (!comercioId) {
             return NextResponse.json({ error: 'ID de comercio inválido' }, { status: 400 })
        }

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
        
        // Verificar autenticación
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
        }
        
        console.log(`[POST /seguir] User: ${user.id}, Comercio: ${comercioId}`)

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
    context: { params: Promise<{ id: string }> }
) {
    try {
        const { id } = await context.params
        const comercioId = id

        if (!comercioId) {
             return NextResponse.json({ error: 'ID de comercio inválido' }, { status: 400 })
        }

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
