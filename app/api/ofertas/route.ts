import { createClient } from '@/lib/supabase/route'
import { OfertaMapper } from '@/lib/types'
import { NextResponse } from 'next/server'

/**
 * GET /api/ofertas
 * 
 * Obtiene la lista de ofertas activas.
 */
export async function GET(request: Request) {
    try {
        const supabase = await createClient()

        // Obtener filtros de la URL (opcional)
        const { searchParams } = new URL(request.url)
        const nivel = searchParams.get('nivel') // Filtrar por nivel
        const limit = parseInt(searchParams.get('limit') || '20')

        let query = supabase
            .from('ofertas')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(limit)

        // Aplicar filtros si existen
        if (nivel) {
            query = query.eq('nivel_requerido', nivel)
        }

        const { data: ofertas, error } = await query

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        // Usar el Mapper para transformar a camelCase (OfertaModel)
        const data = ofertas?.map(OfertaMapper.toDomain)

        return NextResponse.json({ data })
    } catch (error) {
        console.error('Error al obtener ofertas:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * POST /api/ofertas
 * 
 * Crea una nueva oferta.
 */
export async function POST(request: Request) {
    try {
        const supabase = await createClient()

        // Verificar autenticación
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json(
                { error: 'No autorizado' },
                { status: 401 }
            )
        }

        const body = await request.json()

        // Mapear de camelCase (request) a snake_case (DB) usando el Mapper de forma inversa o manual
        // Aquí construimos el objeto para la DB manualmente por simplicidad y seguridad
        const nuevaOfertaInput = {
            comercio: body.comercio,
            titulo: body.titulo,
            descripcion: body.descripcion,
            imageUrl: body.imageUrl,
            fechaInicio: body.fechaInicio || new Date().toISOString(),
            fechaFin: body.fechaFin, // Obligatorio
            nivelRequerido: body.nivelRequerido,
            userId: user.id
        }

        // Validación simple
        if (!nuevaOfertaInput.titulo || !nuevaOfertaInput.fechaFin || !nuevaOfertaInput.comercio) {
            return NextResponse.json(
                { error: 'Faltan campos obligatorios' },
                { status: 400 }
            )
        }

        // Usamos el helper del Mapper para convertir a formato DB
        const dbInsert = OfertaMapper.toDbInsert(nuevaOfertaInput)

        const { data, error } = await supabase
            .from('ofertas')
            .insert(dbInsert)
            .select()
            .single()

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        // Devolver respuesta mapeada al dominio
        return NextResponse.json({
            data: OfertaMapper.toDomain(data),
            message: 'Oferta creada correctamente'
        }, { status: 201 })

    } catch (error) {
        console.error('Error al crear oferta:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
