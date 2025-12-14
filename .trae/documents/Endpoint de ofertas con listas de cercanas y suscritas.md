## Objetivo

* Modificar el endpoint `GET /api/ofertas` para devolver dos listas de ofertas:

  1. `ofertasCercanas`: 10 ofertas ordenadas por "distancia". La distancia se obtendrá en base al user\_id que será el id del comercio que ha publicado la oferta y en su fila de la tabla comercios está la ubicación del comercio.
  2. `ofertasSuscritas`: Ofertas de los comercios a los que el usuario está suscrito (campo `comercios_subs` en tabla `usuarios`).

## Estructura de Respuesta Propuesta

```json
{
  "data": {
    "ofertasCercanas": [...],
    "ofertasSuscritas": [...]
  }
}
```

## Pasos de Implementación

1. **Autenticación**: Verificar usuario para obtener sus suscripciones (`comercios_subs`). Si no está autenticado, `ofertasSuscritas` será vacío.
2. **Obtener Suscripciones**: Consultar la columna `comercios_subs` (JSON) del usuario logueado.
3. **Consulta 1 (Cercanas)**:

   * *Limitación actual*: La tabla `ofertas` no tiene lat/long por lo que hay que obtenerla del comercio.
4. **Consulta 2 (Suscritas)**:

   * Si el usuario tiene `comercios_subs` (array de IDs de comercios), hacer una query a `ofertas` filtrando donde `comercio` esté en esa lista.

   * Sin límite o con paginación según se requiera (asumiré traer todas o un límite razonable como 20).
5. **Unificar y Responder**: Combinar ambos resultados en el objeto JSON.

## Detalles Técnicos

* Archivo: `app/api/ofertas/route.ts`

* Requiere `createClient` o `createClientWithToken` para leer el usuario.

* Uso de `Promise.all` para ejecutar las consultas en paralelo si es posible.

## Consideraciones sobre "Distancia"

* El esquema `ofertas` mostrado no tiene columnas de geolocalización hay que obtenerlas a través del comercio (user\_id).

## Plan de Código

```typescript
// app/api/ofertas/route.ts

export async function GET(request: Request) {
  // 1. Auth y params
  const supabase = await createClient()
  const { searchParams } = new URL(request.url)
  const lat = searchParams.get('lat')
  const long = searchParams.get('long')

  // 2. Obtener usuario y sus suscripciones
  const { data: { user } } = await supabase.auth.getUser()
  let suscripciones: string[] = []

  if (user) {
    const { data: usuarioData } = await supabase
      .from('usuarios')
      .select('comercios_subs')
      .eq('id', user.id)
      .single()
    // Parsear JSON a array de strings
    suscripciones = usuarioData?.comercios_subs || []
  }

  // 3. Consultas paralelas
  const [cercanasRes, suscritasRes] = await Promise.all([
    // Query Cercanas (Placeholder: recientes limit 10)
    supabase.from('ofertas').select('*').order('created_at', { ascending: false }).limit(10),
    
    // Query Suscritas (solo si hay subs)
    suscripciones.length > 0 
      ? supabase.from('ofertas').select('*').in('comercio', suscripciones) // Asumiendo 'comercio' es el ID o nombre coincidente
      : Promise.resolve({ data: [], error: null })
  ])

  // 4. Mapeo y Respuesta
  return NextResponse.json({
    data: {
      ofertasCercanas: cercanasRes.data?.map(OfertaMapper.toDomain) || [],
      ofertasSuscritas: suscritasRes.data?.map(OfertaMapper.toDomain) || []
    }
  })
}
```

