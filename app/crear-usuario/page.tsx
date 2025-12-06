'use client'

import { useState } from 'react'

/**
 * Página de prueba - Crear Usuario
 * 
 * Interfaz interactiva para probar el endpoint POST /api/usuarios
 * Requiere ID y Email.
 */
export default function CrearUsuarioPage() {
    const [id, setId] = useState('')
    const [email, setEmail] = useState('')
    const [loading, setLoading] = useState(false)
    const [resultado, setResultado] = useState<any>(null)
    const [error, setError] = useState<string | null>(null)

    async function crearUsuario(e: React.FormEvent) {
        e.preventDefault()

        if (!email.trim() || !id.trim()) {
            setError('El ID y el email son requeridos')
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
                    id: id.trim(),
                    email: email.trim(),
                }),
            })

            const data = await response.json()

            if (response.ok) {
                setResultado(data)
                // Limpiar formulario
                setId('')
                setEmail('')
            } else {
                setError(data.error || 'Error al crear usuario')
            }
        } catch (err) {
            setError('Error de conexión con el servidor')
        } finally {
            setLoading(false)
        }
    }

    function generarDatosAleatorios() {
        const timestamp = Date.now()
        const random = Math.floor(Math.random() * 1000)
        // Generar un UUID v4 falso pero válido para pruebas
        const uuid = crypto.randomUUID()

        setId(uuid)
        setEmail(`usuario${timestamp}${random}@ejemplo.com`)
    }

    return (
        <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-violet-100 p-8">
            <div className="max-w-4xl mx-auto">
                {/* Header */}
                <div className="text-center mb-12">
                    <h1 className="text-4xl font-bold text-gray-900 mb-4">
                        ➕ Crear Nuevo Usuario
                    </h1>
                    <p className="text-lg text-gray-600">
                        Prueba el endpoint <code className="bg-white px-2 py-1 rounded text-sm">POST /api/usuarios</code>
                    </p>
                    <p className="text-sm text-gray-500 mt-2">
                        Requiere <strong>ID</strong> y <strong>Email</strong>
                    </p>
                </div>

                {/* Formulario Principal */}
                <div className="bg-white rounded-2xl shadow-xl p-8 mb-6">
                    <form onSubmit={crearUsuario} className="space-y-6">

                        {/* Campo ID */}
                        <div>
                            <label htmlFor="id" className="block text-sm font-semibold text-gray-700 mb-2">
                                ID del Usuario (UUID) *
                            </label>
                            <input
                                type="text"
                                id="id"
                                value={id}
                                onChange={(e) => setId(e.target.value)}
                                placeholder="Ej: 550e8400-e29b-41d4-a716-446655440000"
                                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono text-sm"
                                disabled={loading}
                                required
                            />
                            <p className="mt-1 text-xs text-gray-500">
                                Debe ser un UUID único
                            </p>
                        </div>

                        {/* Campo Email */}
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
                                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                disabled={loading}
                                required
                            />
                            <p className="mt-1 text-xs text-gray-500">
                                Debe ser un email válido y único
                            </p>
                        </div>

                        {/* Botones */}
                        <div className="flex gap-3">
                            <button
                                type="submit"
                                disabled={loading}
                                className="flex-1 px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                {loading ? '⏳ Creando...' : '✅ Crear Usuario'}
                            </button>

                            <button
                                type="button"
                                onClick={generarDatosAleatorios}
                                disabled={loading}
                                className="px-6 py-3 bg-purple-600 text-white font-medium rounded-lg hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                🎲 Generar UUID y Email
                            </button>
                        </div>
                    </form>
                </div>

                {/* Loading */}
                {loading && (
                    <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg mb-6">
                        <div className="flex items-center">
                            <div className="animate-spin rounded-full h-6 w-6 border-2 border-blue-500 border-t-transparent mr-3"></div>
                            <p className="text-blue-700 font-medium">Procesando solicitud...</p>
                        </div>
                    </div>
                )}

                {/* Error */}
                {error && !loading && (
                    <div className="bg-red-50 border-l-4 border-red-500 p-6 rounded-r-lg mb-6">
                        <div className="flex items-start">
                            <div className="flex-shrink-0">
                                <span className="text-3xl">❌</span>
                            </div>
                            <div className="ml-3">
                                <h3 className="text-lg font-bold text-red-800">Error</h3>
                                <p className="mt-1 text-red-700">{error}</p>
                            </div>
                        </div>
                    </div>
                )}

                {/* Éxito */}
                {resultado && !loading && !error && (
                    <div className="bg-gradient-to-r from-green-50 to-emerald-50 border-l-4 border-green-500 p-6 rounded-r-lg mb-6 animate-fade-in">
                        <div className="flex items-start mb-4">
                            <div className="flex-shrink-0">
                                <span className="text-3xl">✅</span>
                            </div>
                            <div className="ml-3">
                                <h3 className="text-lg font-bold text-green-800">¡Usuario Creado Exitosamente!</h3>
                                <p className="text-sm text-green-700 mt-1">{resultado.message}</p>
                            </div>
                        </div>

                        <div className="space-y-3 ml-11">
                            <div className="grid grid-cols-1 gap-3">
                                <div className="bg-white p-3 rounded-lg border border-green-100">
                                    <p className="text-xs font-semibold text-gray-500 mb-1">ID REGISTRADO</p>
                                    <code className="text-sm text-gray-900 break-all font-mono">{resultado.data.id}</code>
                                </div>
                                <div className="bg-white p-3 rounded-lg border border-green-100">
                                    <p className="text-xs font-semibold text-gray-500 mb-1">EMAIL REGISTRADO</p>
                                    <p className="text-sm text-gray-900">{resultado.data.email}</p>
                                </div>
                            </div>

                            {/* JSON completo */}
                            <details className="mt-4">
                                <summary className="cursor-pointer text-sm font-semibold text-gray-700 hover:text-gray-900 bg-white p-3 rounded-lg border border-gray-200">
                                    Ver JSON completo de la respuesta
                                </summary>
                                <pre className="mt-3 bg-gray-900 text-green-400 p-4 rounded-lg text-xs overflow-x-auto">
                                    {JSON.stringify(resultado, null, 2)}
                                </pre>
                            </details>
                        </div>
                    </div>
                )}

                {/* Información del Endpoint */}
                <div className="bg-white rounded-xl shadow-md p-6">
                    <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center">
                        <span className="text-2xl mr-2">💻</span>
                        Ejemplo de Uso
                    </h3>
                    <pre className="bg-gray-900 text-green-400 p-4 rounded-lg text-xs overflow-x-auto">
                        {`// Ejemplo de llamada al endpoint
const response = await fetch('/api/usuarios', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'usuario@ejemplo.com'
  })
})`}
                    </pre>
                </div>
            </div>
        </div>
    )
}
