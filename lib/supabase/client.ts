import { createBrowserClient } from '@supabase/ssr'

/**
 * Cliente de Supabase para componentes del lado del cliente (Client Components)
 * 
 * Este cliente utiliza las cookies del navegador y es seguro para usar en componentes
 * que se ejecutan en el navegador del usuario.
 * 
 * @example
 * ```tsx
 * 'use client'
 * 
 * import { createClient } from '@/lib/supabase/client'
 * 
 * export default function ClientComponent() {
 *   const supabase = createClient()
 *   
 *   const fetchData = async () => {
 *     const { data, error } = await supabase.from('tabla').select()
 *   }
 *   
 *   return <div>...</div>
 * }
 * ```
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
