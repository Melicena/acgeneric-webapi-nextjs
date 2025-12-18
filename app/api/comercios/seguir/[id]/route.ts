import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const supabase = await createClient()

    // 1. Autenticación
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return NextResponse.json(
        { error: 'No autorizado. Debes iniciar sesión para seguir un comercio.' },
        { status: 401 }
      )
    }

    // 2. Insertar en la tabla comercios_seguidos
    // Usamos upsert o ignoramos duplicados si ya existe
    const { error } = await supabase
      .from('comercios_seguidos')
      .insert({
        user_id: user.id,
        comercio_id: id,
        notifications_enabled: true
      })

    if (error) {
      // Código 23505 es unique_violation (ya lo sigue)
      if (error.code === '23505') {
        return NextResponse.json(
          { message: 'Ya sigues a este comercio' },
          { status: 200 }
        )
      }
      
      console.error('Error al seguir comercio:', error)
      return NextResponse.json(
        { error: 'Error al seguir el comercio' },
        { status: 500 }
      )
    }

    return NextResponse.json(
      { message: 'Comercio seguido exitosamente' },
      { status: 200 }
    )

  } catch (error) {
    console.error('Error interno en POST /api/comercios/seguir/[id]:', error)
    return NextResponse.json(
      { error: 'Error interno del servidor' },
      { status: 500 }
    )
  }
}
