import { createClient } from '@/lib/supabase/server'

/**
 * Ejemplo de Server Component que usa Supabase
 * 
 * Este componente demuestra cómo:
 * - Usar el cliente de Supabase en un Server Component
 * - Realizar consultas a la base de datos del lado del servidor
 * - Aprovechar el cache de Next.js para optimizar las consultas
 */
export default async function SupabaseServerExample() {
    const supabase = await createClient()

    // Consultar datos del lado del servidor
    const { data: usuarios, error } = await supabase
        .from('usuarios')
        .select('*')
        .limit(10)

    if (error) {
        return (
            <div className="p-8">
                <p className="text-red-500">Error: {error.message}</p>
                <p className="text-sm text-gray-600 mt-2">
                    Asegúrate de haber configurado las variables de entorno correctamente
                    y de que la tabla 'usuarios' existe en tu base de datos.
                </p>
            </div>
        )
    }

    return (
        <div className="p-8">
            <h2 className="text-2xl font-bold mb-4">Server Component - Datos de Supabase</h2>

            <div className="space-y-2">
                {usuarios && usuarios.length === 0 ? (
                    <p>No hay datos disponibles</p>
                ) : (
                    usuarios?.map((usuario, index) => (
                        <div key={usuario.id || index} className="p-4 border rounded">
                            <pre className="text-sm">{JSON.stringify(usuario, null, 2)}</pre>
                        </div>
                    ))
                )}
            </div>
        </div>
    )
}
