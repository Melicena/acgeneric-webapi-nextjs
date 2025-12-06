'use client'

import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'

/**
 * Ejemplo de componente cliente que usa Supabase
 * 
 * Este componente demuestra cómo:
 * - Usar el cliente de Supabase en un Client Component
 * - Realizar consultas a la base de datos
 * - Manejar estados de carga y error
 * - Suscribirse a cambios en tiempo real
 */
export default function SupabaseClientExample() {
    const [data, setData] = useState<any[]>([])
    const [loading, setLoading] = useState(true)
    const [error, setError] = useState<string | null>(null)

    const supabase = createClient()

    useEffect(() => {
        fetchData()

        // Ejemplo de suscripción en tiempo real
        // Descomenta si quieres usar Realtime
        /*
        const channel = supabase
          .channel('custom-all-channel')
          .on(
            'postgres_changes',
            { event: '*', schema: 'public', table: 'usuarios' },
            (payload) => {
              console.log('Cambio detectado:', payload)
              fetchData() // Recargar datos cuando hay cambios
            }
          )
          .subscribe()
    
        return () => {
          supabase.removeChannel(channel)
        }
        */
    }, [])

    async function fetchData() {
        try {
            setLoading(true)
            setError(null)

            // Reemplaza 'usuarios' con el nombre de tu tabla
            const { data, error } = await supabase
                .from('usuarios')
                .select('*')
                .limit(10)

            if (error) throw error

            setData(data || [])
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Error desconocido')
            console.error('Error al cargar datos:', err)
        } finally {
            setLoading(false)
        }
    }

    async function insertData() {
        try {
            const { error } = await supabase
                .from('usuarios')
                .insert({
                    email: 'nuevo@ejemplo.com',
                    nombre: 'Usuario Nuevo'
                })

            if (error) throw error

            // Recargar datos después de insertar
            await fetchData()
        } catch (err) {
            console.error('Error al insertar:', err)
            alert('Error al insertar datos')
        }
    }

    if (loading) {
        return (
            <div className="p-8">
                <p>Cargando datos...</p>
            </div>
        )
    }

    if (error) {
        return (
            <div className="p-8">
                <p className="text-red-500">Error: {error}</p>
                <p className="text-sm text-gray-600 mt-2">
                    Asegúrate de haber configurado las variables de entorno correctamente.
                </p>
            </div>
        )
    }

    return (
        <div className="p-8">
            <h2 className="text-2xl font-bold mb-4">Datos de Supabase</h2>

            <button
                onClick={insertData}
                className="mb-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
                Insertar Datos de Prueba
            </button>

            <div className="space-y-2">
                {data.length === 0 ? (
                    <p>No hay datos disponibles</p>
                ) : (
                    data.map((item, index) => (
                        <div key={item.id || index} className="p-4 border rounded">
                            <pre className="text-sm">{JSON.stringify(item, null, 2)}</pre>
                        </div>
                    ))
                )}
            </div>
        </div>
    )
}
