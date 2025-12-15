import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

/**
 * GET /api/comercios/seguidos
 * 
 * Devuelve la lista de IDs de los comercios que sigue el usuario autenticado.
 * Reemplaza la consulta directa a la tabla 'user_follows' (ahora 'comercios_seguidos').
 */
export async function GET(request: Request) {
    try {
        const supabase = await createClient()
        
        // 1. Verificar autenticación
        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        }

        // 2. Consultar tabla de seguimientos
        const { data: seguidos, error } = await supabase
            .from('comercios_seguidos')
            .select('comercio_id')
            .eq('user_id', user.id)

        if (error) {
            console.error('Error fetching followed commerces:', error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        // 3. Mapear a lista de IDs (strings)
        const ids = seguidos?.map(s => s.comercio_id) || []

        return NextResponse.json(ids)
    } catch (error) {
        console.error('Unexpected error:', error)
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
    }
}
