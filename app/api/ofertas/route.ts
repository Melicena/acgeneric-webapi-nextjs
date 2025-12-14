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

        // 2. Ejecutar consultas en paralelo
        const [ofertasTodasRes, suscritasRes] = await Promise.all([
            // Consulta de Todas las Ofertas con datos de usuario (comercio) para distancia
            supabase
                .from('ofertas')
                .select(`
                    *,
                    comercio:comercios!inner (
                        id,
                        nombre,
                        location
                    )
                `)
                .order('created_at', { ascending: false })
                .limit(50), // Traemos más para poder filtrar/ordenar por distancia en memoria

            // Consulta de Ofertas de Comercios Suscritos
            suscripciones.length > 0
                ? supabase
                    .from('ofertas')
                    .select(`
                        *,
                        comercio:comercios!inner (
                            id,
                            nombre,
                            location
                        )
                    `)
                    .in('comercio', suscripciones)
                    .order('created_at', { ascending: false })
                    .limit(limit)
                : Promise.resolve({ data: [], error: null })
        ])

        // Manejo de errores
        if (ofertasTodasRes.error) {
            console.error('Error obteniendo ofertas:', ofertasTodasRes.error)
        }

        // 3. Procesar Ofertas Cercanas
        // TODO: Implementar lógica de cálculo de distancia real
        // const userLat = parseFloat(searchParams.get('lat') || '0')
        // const userLong = parseFloat(searchParams.get('long') || '0')
        
        // Si la tabla comercios tiene columna 'location' (lat, long o PostGIS geography), 
        // aquí podemos iterar sobre ofertasTodasRes.data y calcular distancia.
        
        /* Ejemplo de lógica futura:
        const ofertasConDistancia = ofertasTodasRes.data?.map(oferta => {
             const comercioLoc = oferta.comercio?.location // Asumiendo objeto {lat, long}
             const distancia = calcularDistancia(userLat, userLong, comercioLoc.lat, comercioLoc.long)
             return { ...oferta, distancia }
        }).sort((a, b) => a.distancia - b.distancia)
        
        const ofertasCercanas = ofertasConDistancia.slice(0, 10).map(OfertaMapper.toDomain)
        */

        // Por ahora devolvemos las más recientes tal cual vienen de la query
        const ofertasCercanas = ofertasTodasRes.data?.slice(0, 10).map(item => OfertaMapper.toDomain(item)) || []
        const ofertasSuscritas = suscritasRes.data?.map(OfertaMapper.toDomain) || []

        return NextResponse.json({
            data: {
                ofertasCercanas,
                ofertasSuscritas
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
