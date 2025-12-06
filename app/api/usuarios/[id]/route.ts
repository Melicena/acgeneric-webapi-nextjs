import { createClient } from '@/lib/supabase/route'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

/**
 * GET /api/usuarios/[id]
 * 
 * Obtiene un usuario por su ID.
 * LÓGICA DE SINCRONIZACIÓN:
 * 1. Busca en la tabla 'usuarios'.
 * 2. Si no existe, busca en Supabase Auth (requiere Service Role Key).
 * 3. Si existe en Auth, lo crea en la tabla 'usuarios' y lo devuelve.
 */
export async function GET(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params

        if (!id) {
            return NextResponse.json({ error: 'ID es requerido' }, { status: 400 })
        }

        // 1. Intentar obtener el usuario de la tabla pública
        const { data: usuarioExistente, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('id', id)
            .single()

        // Si existe, devolverlo
        if (usuarioExistente) {
            return NextResponse.json({ data: usuarioExistente })
        }

        // 2. Si no existe (PGRST116), intentar recuperarlo de Auth y crearlo
        if (error && error.code === 'PGRST116') {
            console.log(`Usuario ${id} no encontrado en tabla pública. Buscando en Auth...`)

            // Verificar si tenemos la Service Role Key
            const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

            if (!serviceRoleKey) {
                console.error('Falta SUPABASE_SERVICE_ROLE_KEY para sincronización automática')
                return NextResponse.json(
                    { error: 'Usuario no encontrado. Configure SUPABASE_SERVICE_ROLE_KEY para sincronización automática.' },
                    { status: 404 }
                )
            }

            // Crear cliente Admin para acceder a auth.users
            const supabaseAdmin = createAdminClient(
                process.env.NEXT_PUBLIC_SUPABASE_URL!,
                serviceRoleKey,
                {
                    auth: {
                        autoRefreshToken: false,
                        persistSession: false
                    }
                }
            )

            // Buscar usuario en Auth
            const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.getUserById(id)

            if (authError || !authUser.user) {
                return NextResponse.json(
                    { error: 'Usuario no encontrado ni en tabla pública ni en Auth' },
                    { status: 404 }
                )
            }

            // 3. Crear el usuario en la tabla pública
            const email = authUser.user.email

            if (!email) {
                return NextResponse.json(
                    { error: 'El usuario de Auth no tiene email' },
                    { status: 400 }
                )
            }

            console.log(`Usuario encontrado en Auth (${email}). Sincronizando...`)

            const { data: nuevoUsuario, error: createError } = await supabaseAdmin
                .from('usuarios')
                .insert({
                    id: id,
                    email: email.toLowerCase(),
                    // nombre: authUser.user.user_metadata?.full_name || null // Opcional
                })
                .select()
                .single()

            if (createError) {
                console.error('Error al crear usuario sincronizado:', createError)
                // Si falla la creación (ej. email duplicado por alguna razón), devolvemos error
                return NextResponse.json(
                    { error: `Error al sincronizar usuario: ${createError.message}` },
                    { status: 500 }
                )
            }

            return NextResponse.json({
                data: nuevoUsuario,
                message: 'Usuario sincronizado desde Auth exitosamente'
            })
        }

        // Otros errores de base de datos
        return NextResponse.json(
            { error: error?.message || 'Error procesando la solicitud' },
            { status: 500 }
        )

    } catch (error) {
        console.error('Error al obtener usuario:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}

/**
 * PUT /api/usuarios/[id]
 * Actualiza un usuario
 */
export async function PUT(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params
        const body = await request.json()

        if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

        const { data, error } = await supabase
            .from('usuarios')
            .update({
                email: body.email,
                nombre: body.nombre,
            })
            .eq('id', id)
            .select()
            .single()

        if (error) return NextResponse.json({ error: error.message }, { status: 500 })

        return NextResponse.json({ data })
    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}

/**
 * DELETE /api/usuarios/[id]
 * Elimina un usuario
 */
export async function DELETE(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const supabase = await createClient()
        const { id } = await params

        if (!id) return NextResponse.json({ error: 'ID requerido' }, { status: 400 })

        const { error } = await supabase.from('usuarios').delete().eq('id', id)

        if (error) return NextResponse.json({ error: error.message }, { status: 500 })

        return NextResponse.json({ message: 'Usuario eliminado' })
    } catch (error) {
        return NextResponse.json({ error: 'Error interno' }, { status: 500 })
    }
}
