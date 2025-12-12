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
 * PUT /api/usuarios
 * 
 * Ejemplo de Route Handler que actualiza un usuario.
 * Recibe el ID y los datos a actualizar en el body.
 * Soporta actualización parcial de campos.
 */
export async function PUT(request: Request) {
    try {
        const supabase = await createClient()
        const body = await request.json()

        // Autenticación: Intentar obtener usuario por cookies primero, luego por header
        let { data: { user } } = await supabase.auth.getUser()

        // --- DEBUG V2 START ---
        const authHeader = request.headers.get('authorization')
        console.log('DEBUG V2: Checking Auth')
        console.log('DEBUG V2: User from cookies:', user?.id)
        console.log('DEBUG V2: Auth Header present:', !!authHeader)
        if (authHeader) console.log('DEBUG V2: Token prefix:', authHeader.substring(0, 15) + '...')
        // --- DEBUG V2 END ---

        if (!user) {
            if (authHeader) {
                const token = authHeader.replace('Bearer ', '')
                // IMPORTANTE: Al usar getUser(token), necesitamos un cliente nuevo o reconfigurado
                // porque el cliente actual 'supabase' está configurado con cookies vacías/inválidas.
                // Sin embargo, supabase.auth.getUser(token) DEBERÍA funcionar si el token es válido.
                
                const { data: { user: headerUser }, error: headerError } = await supabase.auth.getUser(token)
                
                console.log('DEBUG V2: User from header token:', headerUser?.id)
                if (headerError) console.log('DEBUG V2: Header Error:', headerError)
                
                user = headerUser
            }
        }

        if (!user) {
            return NextResponse.json(
                { error: 'No autorizado' },
                { status: 401 }
            )
        }

        if (!body.id) {
            return NextResponse.json(
                { error: 'ID es requerido en el cuerpo de la petición' },
                { status: 400 }
            )
        }

        // Construir objeto de actualización dinámicamente
        const updateData: any = {}
        if (body.email !== undefined) updateData.email = body.email
        if (body.nombre !== undefined) updateData.nombre = body.nombre
        // Soporte para display_name (snake_case o camelCase)
        if (body.display_name !== undefined) updateData.display_name = body.display_name
        if (body.displayName !== undefined) updateData.display_name = body.displayName

        if (Object.keys(updateData).length === 0) {
            return NextResponse.json(
                { error: 'No se proporcionaron datos para actualizar' },
                { status: 400 }
            )
        }

        const { data, error } = await supabase
            .from('usuarios')
            .update(updateData)
            .eq('id', body.id)
            .select() // No usamos .single() para evitar error si no encuentra registros

        if (error) {
            return NextResponse.json(
                { error: error.message },
                { status: 500 }
            )
        }

        // Verificar si se actualizó algún registro
        if (!data || data.length === 0) {
            return NextResponse.json(
                { error: 'Usuario no encontrado o no tienes permisos para actualizarlo' },
                { status: 404 }
            )
        }

        return NextResponse.json({ data: data[0] })
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
