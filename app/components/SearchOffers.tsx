'use client'

import { useState, useEffect, useRef } from 'react'

interface Oferta {
    id: string
    titulo: string
    descripcion: string
    comercioData?: {
        id: string
        nombre: string
        categorias: string[]
    }
    imageUrl: string
    nivelRequerido: string
    isFollowed?: boolean
}

function useDebounce<T>(value: T, delay: number): T {
    const [debouncedValue, setDebouncedValue] = useState(value)

    useEffect(() => {
        const handler = setTimeout(() => {
            setDebouncedValue(value)
        }, delay)

        return () => {
            clearTimeout(handler)
        }
    }, [value, delay])

    return debouncedValue
}

export default function SearchOffers() {
    const [searchTerm, setSearchTerm] = useState('')
    const [results, setResults] = useState<Oferta[]>([])
    const [loading, setLoading] = useState(false)
    const [hasSearched, setHasSearched] = useState(false)
    const [token, setToken] = useState<string | null>(null)
    
    const debouncedSearchTerm = useDebounce(searchTerm, 500)

    useEffect(() => {
        // Simular obtención del token (en una app real vendría de un AuthContext)
        // Por ahora asumimos que si el usuario navega aquí, quizás ya tengamos un token en localStorage o similar.
        // O simplemente lo dejamos null y el botón fallará (o pedirá login).
        // Para este ejercicio, intentaremos leerlo de alguna parte o simplemente manejar el 401.
        // NOTA: En Next.js con Supabase, usaríamos useSession() de @supabase/auth-helpers-react
        const storedToken = localStorage.getItem('sb-access-token') 
        // Ajustar según como se guarde el token en esta app. 
        // Si no hay contexto, asumimos que las llamadas fallarán si no hay cookie httpOnly.
    }, [])
    
    const handleFollow = async (comercioId: string, currentStatus: boolean) => {
        try {
            // Optimistic update
            setResults(prev => prev.map(o => {
                if (o.comercioData?.id === comercioId) {
                    return { ...o, isFollowed: !currentStatus }
                }
                return o
            }))

            const method = currentStatus ? 'DELETE' : 'POST'
            const res = await fetch(`/api/comercios/${comercioId}/seguir`, {
                method
            })

            if (!res.ok) {
                // Revertir si falla
                if (res.status === 401) {
                    alert('Debes iniciar sesión para seguir comercios')
                }
                throw new Error('Error al actualizar seguimiento')
            }
        } catch (error) {
            console.error(error)
            // Revertir
            setResults(prev => prev.map(o => {
                if (o.comercioData?.id === comercioId) {
                    return { ...o, isFollowed: currentStatus }
                }
                return o
            }))
        }
    }
    
    useEffect(() => {
        const fetchOffers = async () => {
            setLoading(true)
            try {
                // Si está vacío, traemos las "todas" o nada, según preferencia.
                // El usuario pide "filtrar", así que si está vacío podríamos mostrar las recientes (comportamiento default API)
                const queryParam = debouncedSearchTerm ? `?search=${encodeURIComponent(debouncedSearchTerm)}` : '?limit=10'
                
                const res = await fetch(`/api/ofertas${queryParam}`)
                if (!res.ok) throw new Error('Error al buscar')
                
                const json = await res.json()
                // La API devuelve { data: { ofertasCercanas: [], ofertasSuscritas: [] } }
                // Para la búsqueda general, usamos ofertasCercanas (que contiene los resultados filtrados)
                setResults(json.data.ofertasCercanas || [])
            } catch (error) {
                console.error(error)
                setResults([])
            } finally {
                setLoading(false)
                setHasSearched(true)
            }
        }

        fetchOffers()
    }, [debouncedSearchTerm])

    return (
        <div className="w-full max-w-4xl mx-auto p-4">
            <div className="mb-8">
                <label htmlFor="search" className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-2">
                    Buscar ofertas
                </label>
                <div className="relative">
                    <input
                        type="text"
                        id="search"
                        className="block w-full p-4 pl-10 text-sm text-gray-900 border border-gray-300 rounded-lg bg-gray-50 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
                        placeholder="Buscar por comercio o título..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                    <div className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                        <svg aria-hidden="true" className="w-5 h-5 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                        </svg>
                    </div>
                </div>
                {loading && <p className="mt-2 text-sm text-gray-500">Buscando...</p>}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {results.map((oferta) => (
                    <div key={oferta.id} className="bg-white dark:bg-gray-800 rounded-lg shadow-md overflow-hidden border border-gray-200 dark:border-gray-700 hover:shadow-lg transition-shadow">
                        <div className="h-48 w-full relative">
                            <img 
                                src={oferta.imageUrl || 'https://via.placeholder.com/400x300'} 
                                alt={oferta.titulo}
                                className="w-full h-full object-cover"
                            />
                            <div className="absolute top-2 right-2 bg-blue-600 text-white text-xs font-bold px-2 py-1 rounded">
                                {oferta.nivelRequerido}
                            </div>
                        </div>
                        <div className="p-4">
                            <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">{oferta.titulo}</h3>
                            <p className="text-sm text-gray-600 dark:text-gray-300 mb-4 line-clamp-2">{oferta.descripcion}</p>
                            
                            <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-100 dark:border-gray-700">
                                <div className="flex flex-col">
                                    <span className="text-sm font-semibold text-gray-900 dark:text-white">
                                        {oferta.comercioData?.nombre || 'Comercio'}
                                    </span>
                                    <span className="text-xs text-gray-500">
                                        {oferta.comercioData?.categorias?.join(', ') || 'Sin categoría'}
                                    </span>
                                </div>
                                {oferta.comercioData?.id && (
                                    <button
                                        onClick={() => handleFollow(oferta.comercioData!.id, !!oferta.isFollowed)}
                                        className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${
                                            oferta.isFollowed
                                                ? 'bg-gray-100 text-gray-800 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-200'
                                                : 'bg-blue-600 text-white hover:bg-blue-700'
                                        }`}
                                    >
                                        {oferta.isFollowed ? 'Siguiendo' : 'Seguir'}
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {!loading && hasSearched && results.length === 0 && (
                <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <h3 className="mt-2 text-sm font-medium text-gray-900 dark:text-white">No se encontraron resultados</h3>
                    <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Prueba con otros términos de búsqueda.</p>
                </div>
            )}
        </div>
    )
}
