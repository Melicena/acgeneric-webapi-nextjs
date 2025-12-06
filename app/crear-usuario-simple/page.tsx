'use client'

import { useState } from 'react'

/**
 * Página de prueba - Crear Usuario (Solo Email)
 * 
 * Esta versión simplificada solo requiere el email,
 * útil si tu tabla aún no tiene la columna 'nombre'
 */
export default function CrearUsuarioSimplePage() {
    const [email, setEmail] = useState('')
    const [loading, setLoading] = useState(false)
    const [resultado, setResultado] = useState<any>(null)
    const [error, setError] = useState<string | null>(null)

    async function crearUsuario(e: React.FormEvent) {
        e.preventDefault()

        if (!email.trim()) {
            setError('El email es requerido')
            return
        }

        setLoading(true)
        setError(null)
        setResultado(null)

        try {
            const response = await fetch('/api/usuarios', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    email: email.trim(),
                    // No enviamos 'nombre' para evitar el error si la columna no existe
                }),
            })

            const data = await response.json()

            if (response.ok) {
                setResultado(data)
                setEmail('') // Limpiar formulario
            } else {
                setError(data.error || 'Error al crear usuario')
            }
        } catch (err) {
            setError('Error de conexión con el servidor')
        } finally {
            setLoading(false)
        }
    }

    function generarEmailAleatorio() {
        const timestamp = Date.now()
        const random = Math.floor(Math.random() * 10000)
        setEmail(`usuario${timestamp}${random}@ejemplo.com`)
    }

    return (
        <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-100 p-8">
            <div className="max-w-3xl mx-auto">
                {/* Header */}
                <div className="text-center mb-8">
                    <h1 className="text-4xl font-bold text-gray-900 mb-4">
                        ✉️ Crear Usuario (Solo Email)
                    </h1>
                    <p className="text-lg text-gray-600 mb-2">
                        Versión simplificada del endpoint <code className="bg-white px-2 py-1 rounded text-sm">POST /api/usuarios</code>
                    </p>
                    <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 inline-block text-left">
                        <p className="text-sm text-yellow-800">
                            💡 <strong>Nota:</strong> Si quieres agregar nombres, sigue las instrucciones en <code>AGREGAR_COLUMNA_NOMBRE.md</code>
                        </p>
                    </div>
                </div>

                {/* Formulario */}
                <div className="bg-white rounded-2xl shadow-xl p-8 mb-6">
                    <form onSubmit={crearUsuario} className="space-y-6">
                        <div>
                            <label htmlFor="email" className="block text-sm font-semibold text-gray-700 mb-2">
                                Email del Usuario *
                            </label>
                            <input
                                type="email"
                                id="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                placeholder="usuario@ejemplo.com"
                                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent text-lg"
                                disabled={loading}
                                required
                            />
                            <p className="mt-2 text-xs text-gray-500">
                                ✓ Formato válido requerido | ✓ Debe ser único
                            </p>
                        </div>

                        <div className="flex gap-3">
                            <button
                                type="submit"
                                disabled={loading}
                                className="flex-1 px-6 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-bold text-lg rounded-lg hover:from-purple-700 hover:to-pink-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg"
                            >
                                {loading ? '⏳ Creando...' : '✅ Crear Usuario'}
                            </button>

                            <button
                                type="button"
                                onClick={generarEmailAleatorio}
                                disabled={loading}
                                className="px-6 py-4 bg-gray-600 text-white font-medium rounded-lg hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                🎲 Generar
                            </button>
                        </div>
                    </form>
                </div>

                {/* Loading */}
                {loading && (
                    <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg mb-6 animate-pulse">
                        <div className="flex items-center">
                            <div className="animate-spin rounded-full h-6 w-6 border-2 border-blue-500 border-t-transparent mr-3"></div>
                            <p className="text-blue-700 font-medium">Creando usuario...</p>
                        </div>
                    </div>
                )}

                {/* Error */}
                {error && !loading && (
                    <div className="bg-red-50 border-l-4 border-red-500 p-6 rounded-r-lg mb-6">
                        <div className="flex items-start">
                            <span className="text-3xl mr-3">❌</span>
                            <div>
                                <h3 className="text-lg font-bold text-red-800">Error</h3>
                                <p className="mt-1 text-red-700">{error}</p>
                                {error.includes('ya está registrado') && (
                                    <button
                                        onClick={generarEmailAleatorio}
                                        className="mt-3 text-sm underline text-red-800 hover:text-red-900"
                                    >
                                        Generar otro email →
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                )}

                {/* Éxito */}
                {resultado && !loading && !error && (
                    <div className="bg-gradient-to-r from-green-50 to-emerald-50 border-l-4 border-green-500 p-6 rounded-r-lg mb-6">
                        <div className="flex items-start mb-4">
                            <span className="text-4xl mr-3">🎉</span>
                            <div>
                                <h3 className="text-2xl font-bold text-green-800">¡Usuario Creado!</h3>
                                <p className="text-green-700 mt-1">{resultado.message}</p>
                            </div>
                        </div>

                        <div className="bg-white p-6 rounded-lg mt-4 space-y-3">
                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <p className="text-xs font-semibold text-gray-500 mb-1">ID GENERADO</p>
                                    <code className="text-xs text-gray-900 break-all bg-gray-100 p-2 rounded block">
                                        {resultado.data.id}
                                    </code>
                                </div>
                                <div>
                                    <p className="text-xs font-semibold text-gray-500 mb-1">EMAIL</p>
                                    <p className="text-sm text-gray-900 bg-gray-100 p-2 rounded">
                                        {resultado.data.email}
                                    </p>
                                </div>
                            </div>

                            <div>
                                <p className="text-xs font-semibold text-gray-500 mb-1">FECHA DE CREACIÓN</p>
                                <p className="text-sm text-gray-900">
                                    {new Date(resultado.data.created_at).toLocaleString('es-ES', {
                                        dateStyle: 'full',
                                        timeStyle: 'medium'
                                    })}
                                </p>
                            </div>

                            <details className="mt-4">
                                <summary className="cursor-pointer text-sm font-semibold text-gray-700 hover:text-gray-900 py-2">
                                    📄 Ver respuesta JSON completa
                                </summary>
                                <pre className="mt-2 bg-gray-900 text-green-400 p-4 rounded-lg text-xs overflow-x-auto">
                                    {JSON.stringify(resultado, null, 2)}
                                </pre>
                            </details>
                        </div>

                        <button
                            onClick={() => {
                                setResultado(null)
                                setEmail('')
                            }}
                            className="mt-4 w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                        >
                            ✨ Crear Otro Usuario
                        </button>
                    </div>
                )}

                {/* Info Card */}
                <div className="bg-white rounded-xl shadow-md p-6">
                    <h3 className="text-lg font-bold text-gray-900 mb-4">💡 Información</h3>
                    <div className="space-y-3 text-sm text-gray-700">
                        <p>
                            <strong>Endpoint:</strong> <code className="bg-gray-100 px-2 py-1 rounded">POST /api/usuarios</code>
                        </p>
                        <p>
                            <strong>Body requerido:</strong> <code className="bg-gray-100 px-2 py-1 rounded">{'{ "email": "..." }'}</code>
                        </p>
                        <p>
                            <strong>Respuesta exitosa:</strong> <code className="bg-green-100 text-green-800 px-2 py-1 rounded">201 Created</code>
                        </p>
                        <div className="pt-3 border-t">
                            <p className="font-semibold mb-2">Enlaces útiles:</p>
                            <div className="space-x-3">
                                <a href="/api/usuarios" target="_blank" className="text-purple-600 hover:underline">
                                    Ver usuarios →
                                </a>
                                <a href="/test-usuario" className="text-purple-600 hover:underline">
                                    Buscar →
                                </a>
                                <a href="/examples" className="text-purple-600 hover:underline">
                                    Ejemplos →
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}
