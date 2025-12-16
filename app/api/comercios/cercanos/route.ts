import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * @swagger
 * /api/comercios/cercanos:
 *   get:
 *     summary: Obtiene todos los comercios ordenados por distancia
 *     description: Retorna un listado paginado de comercios ordenados por cercanía a la ubicación del usuario.
 *     parameters:
 *       - in: query
 *         name: latitud
 *         required: true
 *         schema:
 *           type: number
 *         description: Latitud del usuario
 *       - in: query
 *         name: longitud
 *         required: true
 *         schema:
 *           type: number
 *         description: Longitud del usuario
 *       - in: query
 *         name: page
 *         required: false
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Número de página
 *     responses:
 *       200:
 *         description: Listado de comercios
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         format: uuid
 *                       nombre:
 *                         type: string
 *                       direccion:
 *                         type: string
 *                       telefono:
 *                         type: string
 *                       horario:
 *                         type: string
 *                       imagen_url:
 *                         type: string
 *                       distancia:
 *                         type: number
 *                         description: Distancia en km
 *                       latitud:
 *                         type: number
 *                       longitud:
 *                         type: number
 *                       coordenadas:
 *                         type: object
 *                         properties:
 *                           lat:
 *                             type: number
 *                           lng:
 *                             type: number
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     per_page:
 *                       type: integer
 *                     current_page:
 *                       type: integer
 *                     total_pages:
 *                       type: integer
 *       400:
 *         description: Parámetros inválidos
 *       500:
 *         description: Error del servidor
 */
export async function GET(request: Request) {
    try {
        const { searchParams } = new URL(request.url)
        const latParam = searchParams.get('latitud')
        const longParam = searchParams.get('longitud')
        const pageParam = searchParams.get('page')

        // Validación de parámetros
        if (!latParam || !longParam) {
            return NextResponse.json(
                { error: 'Parámetros requeridos: latitud, longitud' },
                { status: 400 }
            )
        }

        const lat = parseFloat(latParam)
        const long = parseFloat(longParam)
        const page = parseInt(pageParam || '1')
        const pageSize = 20

        if (isNaN(lat) || isNaN(long)) {
            return NextResponse.json(
                { error: 'Coordenadas inválidas' },
                { status: 400 }
            )
        }

        if (isNaN(page) || page < 1) {
            return NextResponse.json(
                { error: 'Número de página inválido' },
                { status: 400 }
            )
        }

        const supabase = await createClient()

        // Llamada a la función RPC de Supabase (PostGIS)
        const { data, error } = await supabase.rpc('get_comercios_sorted_by_distance', {
            user_lat: lat,
            user_long: long,
            page_number: page,
            page_size: pageSize
        })

        if (error) {
            console.error('Error en RPC get_comercios_sorted_by_distance:', error)
            return NextResponse.json(
                { error: 'Error al obtener comercios cercanos', details: error.message },
                { status: 500 }
            )
        }

        // Procesar resultados y paginación
        // Nota: La función RPC devuelve el total_count en cada fila.
        // Si no hay datos, data es un array vacío.
        
        let totalRecords = 0
        let formattedData = []

        if (data && data.length > 0) {
            totalRecords = data[0].total_count
            formattedData = data.map((item: any) => ({
                id: item.id,
                nombre: item.nombre,
                direccion: item.direccion,
                telefono: item.telefono,
                horario: item.horario,
                imagen_url: item.imagen_url,
                distancia: item.distancia_km,
                latitud: item.latitud,
                longitud: item.longitud,
                coordenadas: {
                    lat: item.latitud,
                    lng: item.longitud
                }
            }))
        }

        const totalPages = Math.ceil(totalRecords / pageSize)

        // Respuesta con Cache-Control headers
        // Cacheamos por 60 segundos en CDN/Browser, y permitimos stale por 5 minutos
        return NextResponse.json(
            {
                data: formattedData,
                pagination: {
                    total: totalRecords,
                    per_page: pageSize,
                    current_page: page,
                    total_pages: totalPages
                }
            },
            {
                headers: {
                    'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300'
                }
            }
        )

    } catch (error) {
        console.error('Error interno en GET /api/comercios/cercanos:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
