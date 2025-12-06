import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Middleware de Next.js para manejar la autenticación de Supabase
 * 
 * Este middleware:
 * 1. Refresca la sesión del usuario en cada solicitud
 * 2. Actualiza las cookies de autenticación automáticamente
 * 3. Redirige a los usuarios según su estado de autenticación
 * 
 * Para activar este middleware, descomenta el código y ajusta
 * la configuración según tus necesidades.
 */
export async function middleware(request: NextRequest) {
    let supabaseResponse = NextResponse.next({
        request,
    })

    const supabase = createServerClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            cookies: {
                getAll() {
                    return request.cookies.getAll()
                },
                setAll(cookiesToSet) {
                    cookiesToSet.forEach(({ name, value, options }) => {
                        request.cookies.set(name, value)
                        supabaseResponse.cookies.set(name, value, options)
                    })
                },
            },
        }
    )

    // Obtener token de la cabecera Authorization si existe (para Apps móviles / Clientes externos)
    const authHeader = request.headers.get('authorization')
    let token = undefined

    if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.split(' ')[1]
    }

    // Recuperar el usuario (usando el token si existe, o las cookies por defecto)
    // getUser(token) validará el JWT enviado en la cabecera
    const {
        data: { user },
    } = await supabase.auth.getUser(token)

    // Validar seguridad solo para rutas API
    if (request.nextUrl.pathname.startsWith('/api')) {
        const apiKey = request.headers.get('x-api-key')
        const validApiKey = process.env.X_API_KEY

        // 1. Validar API Key (Si es válida, dejamos pasar aunque no haya usuario)
        if (apiKey && validApiKey && apiKey === validApiKey) {
            return supabaseResponse
        }

        // 2. Validar sesión Supabase
        if (user) {
            return supabaseResponse
        }

        // Si falla ambas autenticaciones
        return NextResponse.json(
            { error: 'Unauthorized: Invalid API Key or Session' },
            { status: 401 }
        )
    }

    // Para rutas NO API, refrescamos la sesión pero no bloqueamos (a menos que añadas lógica específica)
    // Se mantiene el refresco de sesión implícito en el supabaseResponse que ya trae las cookies actualizadas tras el getUser (aunque no lo llamemos explícitamente arriba para rutas no-api, deberíamos hacerlo para mantener consistencia)

    // NOTA: Para rutas no-API, necesitamos llamar a getUser para que las cookies se refresquen correctamente
    // aunque no usemos el usuario. Si ya lo llamamos arriba dentro del if api, bien, pero si no entra al if, no se llama.
    // Vamos a reestructurar ligeramente para llamar siempre a getUser al principio para el refresco de cookies.

    return supabaseResponse
}

// Configuración del matcher del middleware
// Ajusta según las rutas que necesiten este middleware
export const config = {
    matcher: [
        /*
         * Coincide con todas las rutas de solicitud excepto las que comienzan con:
         * - _next/static (archivos estáticos)
         * - _next/image (archivos de optimización de imágenes)
         * - favicon.ico (archivo favicon)
         * Siéntete libre de modificar este patrón para incluir más rutas.
         */
        '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
    ],
}
