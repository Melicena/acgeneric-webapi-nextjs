# Guía de API para Frontend

Esta guía resume todas las URLs disponibles bajo `"/api"` con ejemplos de uso desde el frontend. Incluye parámetros, autenticación y respuestas típicas.

## Autenticación y seguridad
- Header `Authorization: Bearer <token>`: recomendado para llamadas autenticadas (token de Supabase).
- Header `x-api-key: <clave>`: alternativa si el backend está configurado con `X_API_KEY`.
- Cookies de sesión: en entorno web, el cliente puede usar cookies establecidas por Supabase.
- Nota: Algunas rutas requieren usuario autenticado; otras permiten acceso público.

## Convenciones
- Base URL: relativa al host actual, p.e. `"/api/ofertas"`.
- Content-Type:
  - JSON: `application/json`
  - Subida de archivos: `multipart/form-data`
- Respuestas de error comunes:
  - `400`: petición inválida (campos faltantes o formato incorrecto)
  - `401`: no autenticado o no autorizado
  - `404`: recurso no encontrado
  - `409`: conflicto (duplicados)


---

## /api/ofertas
Rutas para gestionar ofertas y promociones.

### GET /api/ofertas
Obtiene ofertas activas, filtradas opcionalmente por categoría. Devuelve dos listas: `ofertasCercanas` (general/filtrado) y `ofertasSuscritas` (de comercios seguidos).

- Query:
  - `categoria` (opcional): Filtro por categoría de comercio. 
    - `"todas"`: devuelve todas.
    - `"<valor>"`: devuelve solo ofertas de comercios en esa categoría.
  - `limit` (opcional, por defecto `20`): Cantidad de elementos.
  - `offset` (opcional, por defecto `0`): Desplazamiento para paginación.

- Autenticación: Opcional (si está autenticado, devuelve `ofertasSuscritas`).

Ejemplo `fetch`:
```ts
// Obtener todas
const res = await fetch('/api/ofertas?categoria=todas&limit=10&offset=0');
const data = await res.json();

// Filtrar por categoría
const res2 = await fetch('/api/ofertas?categoria=Restaurante');
```

Respuesta típica:
```json
{
  "data": {
    "ofertasCercanas": [
      {
        "id": "uuid",
        "titulo": "2x1 en Cenas",
        "comercio": "uuid-comercio",
        "comercioData": {
           "id": "uuid-comercio",
           "nombre": "Restaurante X",
           "categorias": ["Restaurante", "Italiana"]
        },
        "descripcion": "...",
        "imageUrl": "...",
        "fechaInicio": "...",
        "fechaFin": "...",
        "nivelRequerido": "FREE"
      }
    ],
    "ofertasSuscritas": []
  },
  "meta": {
    "page": 1,
    "limit": 10,
    "total": null
  }
}
```

### POST /api/ofertas
Crea una nueva oferta.
- Body (JSON): `comercio`, `titulo`, `descripcion`, `imageUrl`, `fechaFin`, `nivelRequerido`.
- Autenticación: Requerida.

---

## /api/noticias
Rutas para gestionar noticias.

### GET /api/noticias
- Query:
  - `limit` (opcional, por defecto `20`)
- Autenticación: no obligatoria.

Ejemplo `fetch`:
```ts
const res = await fetch('/api/noticias?limit=6');
const items = await res.json();
```

Respuesta típica:
```json
[
  {
    "id": "uuid",
    "titulo": "Nueva actualización",
    "descripcion": "Detalles...",
    "imageUrl": "https://.../imagen.jpg",
    "url": "https://.../post",
    "createdAt": "2025-01-01T00:00:00Z"
  }
]
```

### POST /api/noticias
- Body (JSON):
  - Requeridos: `titulo`, `descripcion`, `imageUrl`
  - Opcional: `url`
- Autenticación: requiere usuario Supabase.

Ejemplo `fetch`:
```ts
await fetch('/api/noticias', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    titulo: 'Nueva promo',
    descripcion: 'Aprovecha esta semana',
    imageUrl: 'https://.../banner.png',
    url: 'https://.../detalle'
  })
});
```

---

## /api/ofertas
Rutas para gestionar ofertas.

### GET /api/ofertas
- Query:
  - `nivel` (opcional)
  - `limit` (opcional, por defecto `20`)
- Autenticación: no obligatoria.

Ejemplo `fetch`:
```ts
const res = await fetch('/api/ofertas?nivel=2&limit=10');
const ofertas = await res.json();
```

### POST /api/ofertas
- Body (JSON):
  - Requeridos: `titulo`, `fechaFin`, `comercio`
  - Opcionales: `descripcion`, `imageUrl`, `fechaInicio` (por defecto `now`), `nivelRequerido`
- Autenticación: requiere usuario Supabase.

Ejemplo `fetch`:
```ts
await fetch('/api/ofertas', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    titulo: '2x1 en café',
    descripcion: 'Solo miércoles',
    comercio: 'Cafetería Z',
    fechaFin: '2025-12-31'
  })
});
```

---

## /api/usuarios
Rutas para gestionar usuarios.

### GET /api/usuarios
- Query:
  - `limit` (opcional, por defecto `10`)
- Autenticación: no obligatoria.

Ejemplo:
```ts
const res = await fetch('/api/usuarios?limit=10');
const usuarios = await res.json();
```

### POST /api/usuarios
- Body (JSON):
  - Requeridos: `id`, `email`
  - Valida formato y evita duplicados (`409` en conflicto)
- Autenticación: no obligatoria.

Ejemplo:
```ts
await fetch('/api/usuarios', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ id: 'uuid', email: 'user@example.com' })
});
```

### PUT /api/usuarios
- Body (JSON):
  - Requerido: `id`
  - Opcionales: `email`, `nombre`, `displayName` (o `display_name`)
- Autenticación: requiere usuario Supabase; acepta `Authorization: Bearer <token>`.

Ejemplo:
```ts
await fetch('/api/usuarios', {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({ id: 'uuid', nombre: 'Nuevo Nombre' })
});
```

### DELETE /api/usuarios
- Query:
  - `id` (requerido)
- Autenticación: no obligatoria.

Ejemplo:
```ts
await fetch('/api/usuarios?id=uuid', { method: 'DELETE' });
```

---

## /api/usuarios/[id]
Acceso a un usuario específico por `id`.

### GET /api/usuarios/:id
- Path param: `id` (requerido)
- Autenticación: no obligatoria.
- Respuestas:
  - `200`: usuario encontrado
  - `404`: no existe

Ejemplo:
```ts
const res = await fetch('/api/usuarios/uuid');
const usuario = await res.json();
```

### PUT /api/usuarios/:id
- Path param: `id` (requerido)
- Body (JSON): `email` y/o `nombre` (opcionales)
- Autenticación: según implementación actual, no verifica explícitamente, pero se recomienda usar token.

Ejemplo:
```ts
await fetch('/api/usuarios/uuid', {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({ nombre: 'Nombre Actualizado' })
});
```

### DELETE /api/usuarios/:id
- Path param: `id` (requerido)
- Autenticación: no obligatoria.

Ejemplo:
```ts
await fetch('/api/usuarios/uuid', { method: 'DELETE' });
```

---

## /api/usuarios/[id]/avatar
Subida de avatar del usuario.

### POST /api/usuarios/:id/avatar
- Path param: `id` (requerido)
- FormData:
  - `file` (requerido) — tipos permitidos: `image/png`, `image/jpeg`, `image/webp`
- Autenticación:
  - Requiere usuario Supabase
  - El `user.id` debe coincidir con `id`

Ejemplo `fetch` con `FormData`:
```ts
const fileInput = document.querySelector('input[type=file]') as HTMLInputElement;
const file = fileInput.files?.[0];
const form = new FormData();
form.append('file', file!);

const res = await fetch('/api/usuarios/uuid/avatar', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` },
  body: form
});
const updated = await res.json();
```

Ejemplo `curl`:
```bash
curl -X POST '/api/usuarios/uuid/avatar' \
  -H "Authorization: Bearer <token>" \
  -F "file=@/ruta/al/archivo.jpg"
```

Respuesta típica:
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "avatarUrl": "https://.../avatars/uuid.webp",
  "updatedAt": "2025-01-01T00:00:00Z"
}
```

---

## Recomendaciones de uso en frontend
- Reutilizar un cliente `fetch` que añada automáticamente `Authorization` cuando el usuario esté logueado.
- Manejar estados de carga y errores (`401`, `404`, `409`) mostrando mensajes claros.
- Para archivos, evitar mezclar `Content-Type: application/json` con `FormData`; el navegador lo establece automáticamente.
- Limitar `limit` en listados para paginación y rendimiento.

## Notas adicionales
- El backend usa Supabase Storage (bucket `avatars`) y Row Level Security en algunas operaciones. Usar siempre el token del usuario para operaciones sensibles.
- Si se habilita `x-api-key`, añadirlo en las llamadas del backend-to-backend o en despliegues controlados.

---

## /api/comercios/[id]/seguir
Gestión de seguimiento de comercios.

### POST /api/comercios/:id/seguir
Permite al usuario autenticado seguir a un comercio.
- Path param: `id` (UUID del comercio)
- Autenticación: Requerida (Token Bearer).

Ejemplo `fetch`:
```ts
await fetch('/api/comercios/uuid-comercio/seguir', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### DELETE /api/comercios/:id/seguir
Permite al usuario autenticado dejar de seguir a un comercio.
- Path param: `id` (UUID del comercio)
- Autenticación: Requerida (Token Bearer).

Ejemplo `fetch`:
```ts
await fetch('/api/comercios/uuid-comercio/seguir', {
  method: 'DELETE',
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```


