import { createClient, createClientWithToken } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * @swagger
 * /api/comercios:
 *   post:
 *     summary: Crear un nuevo comercio
 *     description: Crea un nuevo comercio con imagen y ubicación. Requiere autenticación.
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               nombre:
 *                 type: string
 *               descripcion:
 *                 type: string
 *               telefono:
 *                 type: string
 *               direccion:
 *                 type: string
 *               latitud:
 *                 type: number
 *               longitud:
 *                 type: number
 *               categorias:
 *                 type: array
 *                 items:
 *                   type: string
 *               imagen:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Comercio creado exitosamente
 *       400:
 *         description: Datos inválidos
 *       401:
 *         description: No autorizado
 *       500:
 *         description: Error del servidor
 */
export async function POST(request: Request) {
    try {
        let supabase = await createClient()
        
        // 1. Autenticación (Dual: Cookie o Bearer Token)
        let { data: { user } } = await supabase.auth.getUser()

        if (!user) {
            const authHeader = request.headers.get('authorization')
            if (authHeader) {
                const token = authHeader.replace('Bearer ', '')
                supabase = await createClientWithToken(token)
                const { data: { user: headerUser } } = await supabase.auth.getUser()
                user = headerUser
            }
        }

        if (!user) {
            return NextResponse.json(
                { error: 'No autorizado. Debes iniciar sesión para crear un comercio.' },
                { status: 401 }
            )
        }

        // 2. Obtener datos del FormData
        const formData = await request.formData()
        const nombre = formData.get('nombre') as string
        const descripcion = formData.get('descripcion') as string
        const telefono = formData.get('telefono') as string
        const direccion = formData.get('direccion') as string
        const latitudStr = formData.get('latitud') as string
        const longitudStr = formData.get('longitud') as string
        const categoriasStr = formData.get('categorias') as string
        const imagenFile = formData.get('imagen') as File

        // 3. Validaciones básicas
        if (!nombre || !direccion || !telefono || !latitudStr || !longitudStr || !imagenFile) {
            return NextResponse.json(
                { error: 'Faltan campos obligatorios (nombre, direccion, telefono, latitud, longitud, imagen)' },
                { status: 400 }
            )
        }

        const latitud = parseFloat(latitudStr)
        const longitud = parseFloat(longitudStr)

        if (isNaN(latitud) || isNaN(longitud)) {
            return NextResponse.json(
                { error: 'Latitud o longitud inválidas' },
                { status: 400 }
            )
        }

        // Parsear categorías (asumiendo JSON array o string separado por comas)
        let categorias: string[] = []
        if (categoriasStr) {
            try {
                // Intentar parsear como JSON
                const parsed = JSON.parse(categoriasStr)
                if (Array.isArray(parsed)) {
                    categorias = parsed
                } else {
                    categorias = [categoriasStr]
                }
            } catch (e) {
                // Si falla JSON, intentar separar por comas
                categorias = categoriasStr.split(',').map(c => c.trim()).filter(c => c.length > 0)
            }
        }

        // 4. Subir imagen a Supabase Storage
        // Usaremos el bucket 'comercios' (o 'images' si prefieres, pero 'comercios' es más organizado)
        // Ruta: {user_id}/{timestamp}-{filename}
        const fileExt = imagenFile.name.split('.').pop()
        const fileName = `${user.id}/${Date.now()}.${fileExt}`
        
        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('comercios')
            .upload(fileName, imagenFile, {
                cacheControl: '3600',
                upsert: false
            })

        if (uploadError) {
            console.error('Error subiendo imagen:', uploadError)
            return NextResponse.json(
                { error: 'Error al subir la imagen', details: uploadError.message },
                { status: 500 }
            )
        }

        // Obtener URL pública de la imagen
        const { data: { publicUrl } } = supabase.storage
            .from('comercios')
            .getPublicUrl(fileName)


        // 5. Insertar en base de datos
        // Nota: El trigger 'sync_location_trigger' se encargará de llenar la columna 'location'
        // basándose en latitud/longitud.
        const { data: comercio, error: insertError } = await supabase
            .from('comercios')
            .insert({
                nombre,
                descripcion,
                telefono,
                horario: 'Por definir', // Valor por defecto si no viene en el form
                direccion,
                latitud,
                longitud,
                categorias,
                imagen_url: publicUrl,
                owner_id: user.id,
                is_approved: false // Por defecto requiere aprobación, o true si prefieres
            })
            .select()
            .single()

        if (insertError) {
            console.error('Error insertando comercio:', insertError)
            // Si falla la inserción, podríamos querer borrar la imagen subida para no dejar basura,
            // pero por simplicidad lo dejaremos así por ahora.
            return NextResponse.json(
                { error: 'Error al crear el comercio en base de datos', details: insertError.message },
                { status: 500 }
            )
        }

        return NextResponse.json(comercio, { status: 201 })

    } catch (error) {
        console.error('Error interno en POST /api/comercios:', error)
        return NextResponse.json(
            { error: 'Error interno del servidor' },
            { status: 500 }
        )
    }
}
