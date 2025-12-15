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

        // Obtener filtros de la URL
        const { searchParams } = new URL(request.url)
        const limit = parseInt(searchParams.get('limit') || '20')
        const offset = parseInt(searchParams.get('offset') || '0')
        const category = searchParams.get('categoria')

        console.log(`[GET /api/ofertas] Params - category: ${category}, limit: ${limit}, offset: ${offset}`)

        // 1. Obtener usuario autenticado y sus suscripciones
        const { data: { user } } = await supabase.auth.getUser()
        let suscripciones: string[] = []

        if (user) {
            const { data: usuarioData } = await supabase
                .from('usuarios')
                .select('comercios_subs')
                .eq('id', user.id)
                .single()

            // Asegurarnos de que sea un array de strings (IDs de comercios)
            if (usuarioData?.comercios_subs && Array.isArray(usuarioData.comercios_subs)) {
                suscripciones = usuarioData.comercios_subs as string[]
            }
        }

        // 2. Preparar queries
        // Consulta de Todas las Ofertas (con filtro opcional)
        let queryTodas = supabase
            .from('ofertas')
            .select(`
                *,
                comercio:comercios!inner (
                    id,
                    nombre,
                    location,
                    categorias
                )
            `)
            .order('created_at', { ascending: false })
            .range(offset, offset + limit - 1)

        if (category && category !== 'Todas') {
            // Si categorias es array, usamos contains.
            queryTodas = queryTodas.contains('comercio.categorias', [category])
        }

        // Consulta de Ofertas Suscritas
        let querySuscritas = null
        if (suscripciones.length > 0) {
            querySuscritas = supabase
                .from('ofertas')
                .select(`
                    *,
                    comercio:comercios!inner (
                        id,
                        nombre,
                        location,
                        categorias
                    )
                `)
                .in('comercio', suscripciones)
                .order('created_at', { ascending: false })
                .limit(limit)

            if (category && category !== 'Todas') {
                querySuscritas = querySuscritas.contains('comercio.categorias', [category])
            }
        }

        // 3. Ejecutar consultas en paralelo
        const [ofertasTodasRes, suscritasRes] = await Promise.all([
            queryTodas,
            querySuscritas ? querySuscritas : Promise.resolve({ data: [], error: null })
        ])

        // Manejo de errores
        if (ofertasTodasRes.error) {
            console.error('Error obteniendo ofertas:', ofertasTodasRes.error)
            // No fallamos toda la request, devolvemos array vacío
        }

        // 4. Mapear resultados
        // Nota: OfertaMapper.toDomain ahora maneja el objeto 'comercio' anidado
        const ofertasCercanas = ofertasTodasRes.data?.map(item => OfertaMapper.toDomain(item)) || []
        const ofertasSuscritas = suscritasRes?.data?.map(item => OfertaMapper.toDomain(item)) || []

        return NextResponse.json({
            data: {
                ofertasCercanas,
                ofertasSuscritas
            },
            meta: {
                page: Math.floor(offset / limit) + 1,
                limit,
                total: ofertasTodasRes.count // Solo si agregamos count: 'exact' a la query, por ahora null
            }
        })

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
