'use client'

import { useState } from 'react'

/**
 * Página de prueba de API - Consultar Usuario por ID
 * 
 * Esta página demuestra cómo usar el endpoint GET /api/usuarios/[id]
 */
export default function TestUsuarioPage() {
    const [userId, setUserId] = useState('')
    const [usuario, setUsuario] = useState<any>(null)
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState<string | null>(null)

    async function buscarUsuario() {
        if (!userId.trim()) {
            setError('Por favor ingresa un ID')
            return
        }

        setLoading(true)
        setError(null)
        setUsuario(null)

        try {
            const response = await fetch(`/api/usuarios/${userId.trim()}`)
            const result = await response.json()

            if (response.ok) {
                setUsuario(result.data)
            } else {
                setError(result.error || 'Error al obtener usuario')
            }
        } catch (err) {
            setError('Error de conexión')
        } finally {
            setLoading(false)
        }
    }

    async function obtenerPrimerUsuario() {
        setLoading(true)
        setError(null)

        try {
            const response = await fetch('/api/usuarios?limit=1')
            const result = await response.json()

            if (response.ok && result.data.length > 0) {
                const primerUsuario = result.data[0]
                setUserId(primerUsuario.id)
                setUsuario(primerUsuario)
            } else {
                setError('No hay usuarios en la base de datos')
            }
        } catch (err) {
            setError('Error de conexión')
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
            <div className="max-w-4xl mx-auto">
                {/* Header */}
                <div className="text-center mb-12">
                    <h1 className="text-4xl font-bold text-gray-900 mb-4">
                        🔍 Consultar Usuario por ID
                    </h1>
                    <p className="text-lg text-gray-600">
                        Prueba el endpoint <code className="bg-white px-2 py-1 rounded text-sm">GET /api/usuarios/[id]</code>
                    </p>
                </div>

                {/* Card Principal */}
                <div className="bg-white rounded-2xl shadow-xl p-8 mb-6">
                    {/* Formulario de búsqueda */}
                    <div className="mb-8">
                        <label htmlFor="userId" className="block text-sm font-semibold text-gray-700 mb-2">
                            ID del Usuario (UUID)
                        </label>
                        <div className="flex gap-3">
                            <input
                                type="text"
                                id="userId"
                                value={userId}
                                onChange={(e) => setUserId(e.target.value)}
                                onKeyDown={(e) => e.key === 'Enter' && buscarUsuario()}
                                placeholder="Ej: 123e4567-e89b-12d3-a456-426614174000"
                                className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                            />
                            <button
                                onClick={buscarUsuario}
                                disabled={loading}
                                className="px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                {loading ? '🔄 Buscando...' : '🔍 Buscar'}
                            </button>
                        </div>
                    </div>

                    {/* Botón de ayuda */}
                    <div className="mb-8">
                        <button
                            onClick={obtenerPrimerUsuario}
                            disabled={loading}
                            className="w-full px-4 py-3 bg-gradient-to-r from-purple-500 to-pink-500 text-white font-medium rounded-lg hover:from-purple-600 hover:to-pink-600 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                        >
                            ✨ Obtener ID de un Usuario de Ejemplo
                        </button>
                    </div>

                    {/* Loader */}
                    {loading && (
                        <div className="text-center py-8">
                            <div className="inline-block animate-spin rounded-full h-12 w-12 border-4 border-blue-500 border-t-transparent"></div>
                            <p className="mt-4 text-gray-600">Cargando...</p>
                        </div>
                    )}

                    {/* Error */}
                    {error && !loading && (
                        <div className="bg-red-50 border-l-4 border-red-500 p-4 rounded-r-lg">
                            <div className="flex items-start">
                                <div className="flex-shrink-0">
                                    <span className="text-2xl">❌</span>
                                </div>
                                <div className="ml-3">
                                    <h3 className="text-sm font-medium text-red-800">Error</h3>
                                    <p className="mt-1 text-sm text-red-700">{error}</p>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Usuario encontrado */}
                    {usuario && !loading && !error && (
                        <div className="bg-gradient-to-r from-green-50 to-emerald-50 border-l-4 border-green-500 p-6 rounded-r-lg">
                            <div className="flex items-start mb-4">
                                <div className="flex-shrink-0">
                                    <span className="text-3xl">✅</span>
                                </div>
                                <div className="ml-3">
                                    <h3 className="text-lg font-bold text-green-800">Usuario Encontrado</h3>
                                </div>
                            </div>

                            <div className="space-y-3 ml-10">
                                <div>
                                    <span className="font-semibold text-gray-700">ID:</span>
                                    <code className="ml-2 bg-white px-2 py-1 rounded text-sm">{usuario.id}</code>
                                </div>
                                <div>
                                    <span className="font-semibold text-gray-700">Email:</span>
                                    <span className="ml-2 text-gray-900">{usuario.email}</span>
                                </div>
                                <div>
                                    <span className="font-semibold text-gray-700">Nombre:</span>
                                    <span className="ml-2 text-gray-900">{usuario.nombre || '(sin nombre)'}</span>
                                </div>
                                <div>
                                    <span className="font-semibold text-gray-700">Creado:</span>
                                    <span className="ml-2 text-gray-900">
                                        {new Date(usuario.created_at).toLocaleString('es-ES')}
                                    </span>
                                </div>
                            </div>

                            {/* JSON completo */}
                            <details className="mt-6 ml-10">
                                <summary className="cursor-pointer text-sm font-semibold text-gray-700 hover:text-gray-900">
                                    Ver JSON completo
                                </summary>
                                <pre className="mt-3 bg-gray-900 text-green-400 p-4 rounded-lg text-xs overflow-x-auto">
                                    {JSON.stringify(usuario, null, 2)}
                                </pre>
                            </details>
                        </div>
                    )}
                </div>

                {/* Información adicional */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {/* Endpoint Info */}
                    <div className="bg-white rounded-xl shadow-md p-6">
                        <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center">
                            <span className="text-2xl mr-2">🔗</span>
                            Endpoint
                        </h3>
                        <div className="space-y-2 text-sm">
                            <div>
                                <span className="font-semibold text-gray-700">Método:</span>
                                <code className="ml-2 bg-green-100 text-green-800 px-2 py-1 rounded">GET</code>
                            </div>
                            <div>
                                <span className="font-semibold text-gray-700">URL:</span>
                                <code className="ml-2 bg-gray-100 px-2 py-1 rounded text-xs break-all">
                                    /api/usuarios/&#123;id&#125;
                                </code>
                            </div>
                        </div>
                    </div>

                    {/* Ejemplo de código */}
                    <div className="bg-white rounded-xl shadow-md p-6">
                        <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center">
                            <span className="text-2xl mr-2">💻</span>
                            Ejemplo de Código
                        </h3>
                        <pre className="bg-gray-900 text-green-400 p-3 rounded text-xs overflow-x-auto">
                            {`const response = await fetch(
  '/api/usuarios/\${id}'
)
const data = await response.json()
console.log(data.data)`}
                        </pre>
                    </div>
                </div>

                {/* Footer con enlace */}
                <div className="mt-8 text-center">
                    <a
                        href="/api/usuarios"
                        target="_blank"
                        className="text-blue-600 hover:text-blue-800 underline"
                    >
                        Ver todos los usuarios →
                    </a>
                    <span className="mx-4 text-gray-400">|</span>
                    <a
                        href="/examples"
                        className="text-blue-600 hover:text-blue-800 underline"
                    >
                        Ver más ejemplos →
                    </a>
                </div>
            </div>
        </div>
    )
}
