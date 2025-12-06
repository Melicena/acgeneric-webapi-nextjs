import SupabaseClientExample from './client-example'
import SupabaseServerExample from './server-example'
import ServerActionExample from './server-action-example'

export const dynamic = "force-dynamic";

/**
 * Página de ejemplos de Supabase
 * 
 * Esta página agrupa todos los ejemplos de uso de Supabase:
 * - Client Component
 * - Server Component
 * - Server Actions
 */
export default function ExamplesPage() {
    return (
        <div className="min-h-screen bg-gray-50">
            <div className="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
                <div className="text-center mb-12">
                    <h1 className="text-4xl font-bold text-gray-900 mb-4">
                        Ejemplos de Supabase
                    </h1>
                    <p className="text-lg text-gray-600">
                        Diferentes formas de usar Supabase en Next.js
                    </p>
                </div>

                <div className="space-y-8">
                    {/* Client Component Example */}
                    <div className="bg-white rounded-lg shadow-md overflow-hidden">
                        <div className="bg-blue-50 px-6 py-3 border-b">
                            <h3 className="text-lg font-semibold text-blue-900">
                                Client Component
                            </h3>
                            <p className="text-sm text-blue-700">
                                Componente que se ejecuta en el navegador
                            </p>
                        </div>
                        <SupabaseClientExample />
                    </div>

                    {/* Server Component Example */}
                    <div className="bg-white rounded-lg shadow-md overflow-hidden">
                        <div className="bg-green-50 px-6 py-3 border-b">
                            <h3 className="text-lg font-semibold text-green-900">
                                Server Component
                            </h3>
                            <p className="text-sm text-green-700">
                                Componente que se ejecuta en el servidor
                            </p>
                        </div>
                        <SupabaseServerExample />
                    </div>

                    {/* Server Action Example */}
                    <div className="bg-white rounded-lg shadow-md overflow-hidden">
                        <div className="bg-purple-50 px-6 py-3 border-b">
                            <h3 className="text-lg font-semibold text-purple-900">
                                Server Actions
                            </h3>
                            <p className="text-sm text-purple-700">
                                Funciones del servidor que se pueden llamar desde el cliente
                            </p>
                        </div>
                        <ServerActionExample />
                    </div>

                    {/* API Route Documentation */}
                    <div className="bg-white rounded-lg shadow-md overflow-hidden">
                        <div className="bg-orange-50 px-6 py-3 border-b">
                            <h3 className="text-lg font-semibold text-orange-900">
                                API Routes
                            </h3>
                            <p className="text-sm text-orange-700">
                                Endpoints REST disponibles
                            </p>
                        </div>
                        <div className="p-8">
                            <div className="space-y-4">
                                <div>
                                    <code className="bg-gray-100 px-2 py-1 rounded text-sm">
                                        GET /api/usuarios?limit=10
                                    </code>
                                    <p className="text-sm text-gray-600 mt-1">
                                        Obtiene una lista de usuarios
                                    </p>
                                </div>
                                <div>
                                    <code className="bg-gray-100 px-2 py-1 rounded text-sm">
                                        POST /api/usuarios
                                    </code>
                                    <p className="text-sm text-gray-600 mt-1">
                                        Crea un nuevo usuario
                                    </p>
                                </div>
                                <div>
                                    <code className="bg-gray-100 px-2 py-1 rounded text-sm">
                                        PUT /api/usuarios?id=xxx
                                    </code>
                                    <p className="text-sm text-gray-600 mt-1">
                                        Actualiza un usuario existente
                                    </p>
                                </div>
                                <div>
                                    <code className="bg-gray-100 px-2 py-1 rounded text-sm">
                                        DELETE /api/usuarios?id=xxx
                                    </code>
                                    <p className="text-sm text-gray-600 mt-1">
                                        Elimina un usuario
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Footer con información adicional */}
                <div className="mt-12 text-center text-sm text-gray-600">
                    <p>
                        Para más información, consulta el archivo{' '}
                        <code className="bg-gray-100 px-2 py-1 rounded">
                            SUPABASE_SETUP.md
                        </code>
                    </p>
                </div>
            </div>
        </div>
    )
}
