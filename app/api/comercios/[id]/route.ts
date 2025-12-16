import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * @swagger
 * /api/comercios/{id}:
 *   get:
 *     summary: Obtener un comercio por ID
 *     description: Retorna los detalles de un comercio específico.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID del comercio
 *     responses:
 *       200:
 *         description: Detalles del comercio
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 id:
 *                   type: string
 *                   format: uuid
 *                 nombre:
 *                   type: string
 *                 descripcion:
 *                   type: string
 *                 direccion:
 *                   type: string
 *                 telefono:
 *                   type: string
 *                 horario:
 *                   type: string
 *                 imagen_url:
 *                   type: string
 *                 latitud:
 *                   type: number
 *                 longitud:
 *                   type: number
 *                 categorias:
 *                   type: array
 *                   items:
 *                     type: string
 *                 is_approved:
 *                   type: boolean
 *       404:
 *         description: Comercio no encontrado
 *       500:
 *         description: Error del servidor
 */
export async function GET(
    request: Request,
    context: { params: Promise<{ id: string }> }
) {
    try {
        const { id } = await context.params

        if (!id) {
            return NextResponse.json(
                { error: 'ID es requerido' },
                { status: 400 }
            )
        }

        const supabase = await createClient()

        const { data: comercio, error } = await supabase
            .from('comercios')
            .select('*')
            .eq('id', id)
            .single()

        if (error) {
            if (error.code === 'PGRST116') {
                return NextResponse.json(
                    { error: 'Comercio no encontrado' },
                    { status: 404 }
                )
            }
            console.error('Error al obtener comercio:', error)
            return NextResponse.json(
                { error: 'Error al obtener comercio', details: error.message },
                { status: 500 }
            )
        }

        return NextResponse.json(comercio)

    } catch (error) {
        console.error('Error interno en GET /api/comercios/[id]:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
