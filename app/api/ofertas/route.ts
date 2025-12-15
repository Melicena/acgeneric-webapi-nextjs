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
        const search = searchParams.get('search') || searchParams.get('q')

        console.log(`[GET /api/ofertas] Params - search: ${search}, category: ${category}, limit: ${limit}, offset: ${offset}`)

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

        // 2. Preparar lógica de búsqueda (si aplica)
        let matchingCommerceIds: string[] = []
        if (search) {
            // Buscamos comercios que coincidan con el nombre
            const { data: comerciosFound } = await supabase
                .from('comercios')
                .select('id')
                .ilike('nombre', `%${search}%`)
            
            if (comerciosFound) {
                matchingCommerceIds = comerciosFound.map(c => c.id)
            }
        }

        // 3. Preparar queries
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

        if (search) {
            // Filtro: Título coincide O Comercio es uno de los encontrados
            if (matchingCommerceIds.length > 0) {
                // Sintaxis OR: titulo ilike OR comercio IN (...)
                // Nota: .or() espera una string con filtros separados por coma.
                // Para 'in', usamos la sintaxis "col.in.(val1,val2)"
                // Pero dentro de .or(), la sintaxis es algo como "titulo.ilike.%val%,comercio.in.(id1,id2)"
                const idsString = matchingCommerceIds.map(id => `"${id}"`).join(',') // Comillas dobles para UUIDs a veces necesarias en filtros raw, pero en PostgREST suele ser sin comillas o con.
                // Probamos sin comillas primero, PostgREST usa (val1,val2). UUIDs no llevan comillas en la URL pero aquí sí en el string raw?
                // Mejor estrategia: .or(`titulo.ilike.%${search}%,comercio.in.(${matchingCommerceIds.join(',')})`)
                // Nota: Si hay muchos IDs, la URL puede ser muy larga.
                queryTodas = queryTodas.or(`titulo.ilike.%${search}%,comercio.in.(${matchingCommerceIds.join(',')})`)
            } else {
                // Si no hay comercios que coincidan, solo buscamos por título
                queryTodas = queryTodas.ilike('titulo', `%${search}%`)
            }
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

            if (search) {
                // Misma lógica de búsqueda para suscritos
                if (matchingCommerceIds.length > 0) {
                    querySuscritas = querySuscritas.or(`titulo.ilike.%${search}%,comercio.in.(${matchingCommerceIds.join(',')})`)
                } else {
                    querySuscritas = querySuscritas.ilike('titulo', `%${search}%`)
                }
            }
        }

        // 4. Ejecutar consultas en paralelo
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
