'use client'

import { crearUsuario } from '@/lib/actions/supabase-actions'
import { useState } from 'react'

/**
 * Ejemplo de componente que usa Server Actions
 * 
 * Este componente demuestra cómo usar Server Actions para
 * interactuar con Supabase sin necesidad de crear endpoints API.
 */
export default function ServerActionExample() {
    const [mensaje, setMensaje] = useState<string>('')
    const [error, setError] = useState<string>('')

    async function handleSubmit(formData: FormData) {
        setMensaje('')
        setError('')

        const resultado = await crearUsuario(formData)

        if (resultado.error) {
            setError(resultado.error)
        } else {
            setMensaje('Usuario creado correctamente')
            // Limpiar el formulario
            const form = document.getElementById('usuario-form') as HTMLFormElement
            form?.reset()
        }
    }

    return (
        <div className="p-8">
            <h2 className="text-2xl font-bold mb-4">Server Action - Crear Usuario</h2>

            <form
                id="usuario-form"
                action={handleSubmit}
                className="space-y-4 max-w-md"
            >
                <div>
                    <label htmlFor="email" className="block text-sm font-medium mb-1">
                        Email *
                    </label>
                    <input
                        type="email"
                        id="email"
                        name="email"
                        required
                        className="w-full px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="usuario@ejemplo.com"
                    />
                </div>

                <div>
                    <label htmlFor="nombre" className="block text-sm font-medium mb-1">
                        Nombre
                    </label>
                    <input
                        type="text"
                        id="nombre"
                        name="nombre"
                        className="w-full px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="Juan Pérez"
                    />
                </div>

                <button
                    type="submit"
                    className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                    Crear Usuario
                </button>

                {mensaje && (
                    <div className="p-3 bg-green-100 text-green-700 rounded">
                        {mensaje}
                    </div>
                )}

                {error && (
                    <div className="p-3 bg-red-100 text-red-700 rounded">
                        {error}
                    </div>
                )}
            </form>
        </div>
    )
}
