import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * GET /api/noticias
 * 
 * Obtiene la lista de noticias ordenadas por fecha de creación descendente.
 */
export async function GET(request: Request) {
    try {
        const supabase = await createClient()

        // Obtener parámetros de paginación si es necesario
        const { searchParams } = new URL(request.url)
        const limitParam = searchParams.get('limit')
        const limit = limitParam ? parseInt(limitParam) : 20

        const { data: noticias, error } = await supabase
            .from('noticias')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(limit)

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        // Mapear los nombres de columnas de la base de datos (snake_case) 
        // a los nombres del modelo en el frontend (camelCase) si es necesario
        const noticiasMapeadas = noticias?.map(noticia => ({
            id: noticia.id,
            titulo: noticia.titulo,
            descripcion: noticia.descripcion,
            imageUrl: noticia.image_url,
            url: noticia.url,
            userId: noticia.user_id,
            createdAt: noticia.created_at
        }))

        return NextResponse.json({ data: noticiasMapeadas })
    } catch (error) {
        console.error('Error al obtener noticias:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * POST /api/noticias
 * 
 * Crea una nueva noticia.
 */
export async function POST(request: Request) {
    try {
        const supabase = await createClient()

        // Verificar autenticación
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json(
                { error: 'No autorizado. Debes iniciar sesión.' },
                { status: 401 }
            )
        }

        const body = await request.json()

        // Validaciones básicas
        if (!body.titulo || !body.descripcion || !body.imageUrl) {
            return NextResponse.json(
                { error: 'Faltan campos obligatorios: titulo, descripcion, imageUrl' },
                { status: 400 }
            )
        }

        // Preparar objeto para insertar (snake_case para la DB)
        const nuevaNoticia = {
            titulo: body.titulo,
            descripcion: body.descripcion,
            image_url: body.imageUrl,
            url: body.url || null,
            user_id: user.id
        }

        const { data, error } = await supabase
            .from('noticias')
            .insert(nuevaNoticia)
            .select()
            .single()

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        // Mapear respuesta
        const noticiaRespuesta = {
            id: data.id,
            titulo: data.titulo,
            descripcion: data.descripcion,
            imageUrl: data.image_url,
            url: data.url,
            userId: data.user_id,
            createdAt: data.created_at
        }

        return NextResponse.json({
            data: noticiaRespuesta,
            message: 'Noticia creada correctamente'
        }, { status: 201 })

    } catch (error) {
        console.error('Error al crear noticia:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
