import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Cliente de Supabase para Route Handlers (API Routes)
 * 
 * Este cliente es específico para rutas API en Next.js y maneja correctamente
 * las cookies en el contexto de Request/Response.
 * 
 * @example
 * ```tsx
 * // app/api/datos/route.ts
 * import { createClient } from '@/lib/supabase/route'
 * import { NextResponse } from 'next/server'
 * 
 * export async function GET(request: Request) {
 *   const supabase = await createClient()
 *   const { data, error } = await supabase.from('tabla').select()
 *   
 *   if (error) {
 *     return NextResponse.json({ error: error.message }, { status: 500 })
 *   }
 *   
 *   return NextResponse.json({ data })
 * }
 * ```
 * 
 * @example POST Request
 * ```tsx
 * export async function POST(request: Request) {
 *   const supabase = await createClient()
 *   const body = await request.json()
 *   
 *   const { data, error } = await supabase
 *     .from('tabla')
 *     .insert(body)
 *   
 *   return NextResponse.json({ data, error })
 * }
 * ```
 */
export async function createClient() {
    const cookieStore = await cookies()

    // En Route Handlers, a veces necesitamos acceder a headers si las cookies fallan
    // o si el cliente envía el token en Authorization header directamente.
    // Aunque createServerClient está diseñado para cookies, podemos intentar
    // inicializarlo de manera estándar primero.
    
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
                        // La operación `setAll` fue llamada desde un Route Handler.
                        // Esto puede ser ignorado si tienes middleware refrescando
                        // las cookies del usuario.
                    }
                },
            },
        }
    )
}

/**
 * Cliente de Supabase inicializado con un token de acceso explícito.
 * Útil cuando la autenticación por cookies falla pero tenemos el header Authorization.
 */
export async function createClientWithToken(accessToken: string) {
    const cookieStore = await cookies()

    return createServerClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            global: {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            },
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
                        // Ignorar
                    }
                },
            },
        }
    )
}
