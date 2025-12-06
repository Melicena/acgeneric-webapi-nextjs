import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * GET /api/usuarios
 * 
 * Ejemplo de Route Handler que obtiene usuarios desde Supabase
 */
export async function GET(request: Request) {
    try {
        const supabase = await createClient()

        // Obtener parámetros de búsqueda de la URL
        const { searchParams } = new URL(request.url)
        const limit = parseInt(searchParams.get('limit') || '10')

        const { data, error } = await supabase
            .from('usuarios')
            .select('*')
            .limit(limit)

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        return NextResponse.json({ data })
    } catch (error) {
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * POST /api/usuarios
 * 
 * Crea un nuevo usuario en la base de datos
 * 
 * @body id (optional/required) - ID del usuario (UUID)
 * @body email (required) - Email del usuario
 * 
 * @example
 * fetch('/api/usuarios', {
 *   method: 'POST',
 *   headers: { 'Content-Type': 'application/json' },
 *   body: JSON.stringify({ id: 'uuid...', email: 'nuevo@ejemplo.com' })
 * })
 */
export async function POST(request: Request) {
    try {
        const supabase = await createClient()
        const body = await request.json()

        // Validación: Email es requerido
        if (!body.email) {
            return NextResponse.json(
                { error: 'El email es requerido' },
                { status: 400 }
            )
        }

        // Validación: ID es requerido (según tu solicitud)
        if (!body.id) {
            return NextResponse.json(
                { error: 'El ID es requerido' },
                { status: 400 }
            )
        }

        // Validación: Formato de email
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        if (!emailRegex.test(body.email)) {
            return NextResponse.json(
                { error: 'El email no tiene un formato válido' },
                { status: 400 }
            )
        }

        // Preparar objeto para insertar
        const usuarioParaInsertar = {
            id: body.id,
            email: body.email.toLowerCase().trim(),
        }

        // Crear el usuario
        const { data, error } = await supabase
            .from('usuarios')
            .insert(usuarioParaInsertar)
            .select()
            .single()

        if (error) {
            // Error de email duplicado o ID duplicado
            if (error.code === '23505') {
                return NextResponse.json(
                    { error: 'El email o ID ya está registrado' },
                    { status: 409 }
                )
            }

            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        return NextResponse.json({
            data,
            message: 'Usuario creado exitosamente'
        }, { status: 201 })
    } catch (error) {
        console.error('Error al crear usuario:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * PUT /api/usuarios?id=xxx
 * 
 * Ejemplo de Route Handler que actualiza un usuario
 */
export async function PUT(request: Request) {
    try {
        const supabase = await createClient()
        const { searchParams } = new URL(request.url)
        const id = searchParams.get('id')

        if (!id) {
            return NextResponse.json(
                { error: 'ID es requerido' },
                { status: 400 }
            )
        }

        const body = await request.json()

        const { data, error } = await supabase
            .from('usuarios')
            .update({
                email: body.email,
                nombre: body.nombre,
            })
            .eq('id', id)
            .select()
            .single()

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        return NextResponse.json({ data })
    } catch (error) {
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * DELETE /api/usuarios?id=xxx
 * 
 * Ejemplo de Route Handler que elimina un usuario
 */
export async function DELETE(request: Request) {
    try {
        const supabase = await createClient()
        const { searchParams } = new URL(request.url)
        const id = searchParams.get('id')

        if (!id) {
            return NextResponse.json(
                { error: 'ID es requerido' },
                { status: 400 }
            )
        }

        const { error } = await supabase
            .from('usuarios')
            .delete()
            .eq('id', id)

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        return NextResponse.json({ message: 'Usuario eliminado correctamente' })
    } catch (error) {
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
