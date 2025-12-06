import { createClient } from '@/lib/supabase/route'
import { CuponMapper } from '@/lib/types'
import { NextResponse } from 'next/server'

/**
 * GET /api/cupones
 * 
 * Obtiene la lista de cupones.
 */
export async function GET(request: Request) {
    try {
        const supabase = await createClient()

        // Filtros opcionales
        const { searchParams } = new URL(request.url)
        const estado = searchParams.get('estado')
        const comercio = searchParams.get('comercio')
        const limit = parseInt(searchParams.get('limit') || '20')

        let query = supabase
            .from('cupones')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(limit)

        if (estado) query = query.eq('estado', estado)
        if (comercio) query = query.ilike('comercio', `%${comercio}%`)

        const { data: cupones, error } = await query

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        const data = cupones?.map(CuponMapper.toDomain)
        return NextResponse.json({ data })
    } catch (error) {
        console.error('Error al obtener cupones:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * POST /api/cupones
 * 
 * Crea un nuevo cupón.
 */
export async function POST(request: Request) {
    try {
        const supabase = await createClient()

        const { data: { user } } = await supabase.auth.getUser()
        if (!user) {
            return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
        }

        const body = await request.json()

        const nuevoCuponInput = {
            nombre: body.nombre,
            imagenUrl: body.imagenUrl,
            descripcion: body.descripcion,
            puntosRequeridos: body.puntosRequeridos || 0,
            storeId: body.storeId,
            fechaFin: body.fechaFin,
            qrCode: body.qrCode,
            nivelRequerido: body.nivelRequerido,
            estado: body.estado || 'ACTIVO',
            comercio: body.comercio,
            userId: user.id
        }

        // Validación simple
        if (!nuevoCuponInput.nombre || !nuevoCuponInput.descripcion || !nuevoCuponInput.comercio) {
            return NextResponse.json(
                { error: 'Faltan campos obligatorios' },
                { status: 400 }
            )
        }

        const dbInsert = CuponMapper.toDbInsert(nuevoCuponInput)

        const { data, error } = await supabase
            .from('cupones')
            .insert(dbInsert)
            .select()
            .single()

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        return NextResponse.json({
            data: CuponMapper.toDomain(data),
            message: 'Cupón creado correctamente'
        }, { status: 201 })

    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}
