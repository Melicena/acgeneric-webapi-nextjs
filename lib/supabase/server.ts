import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

/**
 * Cliente de Supabase para Server Components y Server Actions
 * 
 * Este cliente maneja las cookies del servidor de forma segura y debe ser usado
 * en Server Components, Server Actions, y cualquier código que se ejecute en el servidor.
 * 
 * IMPORTANTE: Esta función es asíncrona en Next.js 15+ debido a que cookies() ahora es async.
 * 
 * @example
 * ```tsx
 * import { createClient } from '@/lib/supabase/server'
 * 
 * export default async function ServerComponent() {
 *   const supabase = await createClient()
 *   const { data, error } = await supabase.from('tabla').select()
 *   
 *   return <div>...</div>
 * }
 * ```
 * 
 * @example Server Action
 * ```tsx
 * 'use server'
 * 
 * import { createClient } from '@/lib/supabase/server'
 * 
 * export async function myAction() {
 *   const supabase = await createClient()
 *   const { data, error } = await supabase.from('tabla').insert({ ... })
 * }
 * ```
 */
export async function createClient() {
    const cookieStore = await cookies()

    return createServerClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            cookies: {
                getAll() {
                    return cookieStore.getAll()
                },
                setAll(cookiesToSet) {
                    try {
                        cookiesToSet.forEach(({ name, value, options }) =>
                            cookieStore.set(name, value, options)
                        )
                    } catch {
                        // La operación `setAll` fue llamada desde un Server Component.
                        // Esto puede ser ignorado si tienes middleware refrescando
                        // las cookies del usuario.
                    }
                },
            },
        }
    )
}
