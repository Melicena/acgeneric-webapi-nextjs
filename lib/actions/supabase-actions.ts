'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

/**
 * Server Actions para interactuar con Supabase
 * 
 * Estas acciones pueden ser llamadas directamente desde componentes cliente
 * sin necesidad de crear endpoints API.
 */

/**
 * Crear un nuevo usuario
 */
export async function crearUsuario(formData: FormData) {
    const supabase = await createClient()

    const email = formData.get('email') as string
    const nombre = formData.get('nombre') as string

    if (!email) {
        return { error: 'El email es requerido' }
    }

    const { data, error } = await supabase
        .from('usuarios')
        .insert({
            email,
            nombre: nombre || null,
        })
        .select()
        .single()

    if (error) {
        return { error: error.message }
    }

    // Revalidar la ruta para actualizar los datos en cache
    revalidatePath('/examples')

    return { data, error: null }
}

/**
 * Actualizar un usuario existente
 */
export async function actualizarUsuario(id: string, formData: FormData) {
    const supabase = await createClient()

    const email = formData.get('email') as string
    const nombre = formData.get('nombre') as string

    const { data, error } = await supabase
        .from('usuarios')
        .update({
            email,
            nombre,
        })
        .eq('id', id)
        .select()
        .single()

    if (error) {
        return { error: error.message }
    }

    revalidatePath('/examples')

    return { data, error: null }
}

/**
 * Eliminar un usuario
 */
export async function eliminarUsuario(id: string) {
    const supabase = await createClient()

    const { error } = await supabase
        .from('usuarios')
        .delete()
        .eq('id', id)

    if (error) {
        return { error: error.message }
    }

    revalidatePath('/examples')

    return { error: null }
}

/**
 * Obtener usuario actual (autenticado)
 */
export async function obtenerUsuarioActual() {
    const supabase = await createClient()

    const {
        data: { user },
        error,
    } = await supabase.auth.getUser()

    if (error) {
        return { user: null, error: error.message }
    }

    return { user, error: null }
}

/**
 * Iniciar sesión
 */
export async function iniciarSesion(formData: FormData) {
    const supabase = await createClient()

    const email = formData.get('email') as string
    const password = formData.get('password') as string

    const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
    })

    if (error) {
        return { error: error.message }
    }

    revalidatePath('/', 'layout')

    return { data, error: null }
}

/**
 * Registrar nuevo usuario
 */
export async function registrarUsuario(formData: FormData) {
    const supabase = await createClient()

    const email = formData.get('email') as string
    const password = formData.get('password') as string

    const { data, error } = await supabase.auth.signUp({
        email,
        password,
    })

    if (error) {
        return { error: error.message }
    }

    revalidatePath('/', 'layout')

    return { data, error: null }
}

/**
 * Cerrar sesión
 */
export async function cerrarSesion() {
    const supabase = await createClient()

    const { error } = await supabase.auth.signOut()

    if (error) {
        return { error: error.message }
    }

    revalidatePath('/', 'layout')

    return { error: null }
}
