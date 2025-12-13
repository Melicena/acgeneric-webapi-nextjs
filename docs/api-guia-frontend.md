# Guía de API para Frontend

Esta guía resume todas las URLs disponibles bajo `"/api"` con ejemplos de uso desde el frontend. Incluye parámetros, autenticación y respuestas típicas.

## Autenticación y seguridad
- Header `Authorization: Bearer <token>`: recomendado para llamadas autenticadas (token de Supabase).
- Header `x-api-key: <clave>`: alternativa si el backend está configurado con `X_API_KEY`.
- Cookies de sesión: en entorno web, el cliente puede usar cookies establecidas por Supabase.
- Nota: Algunas rutas requieren usuario autenticado; otras permiten acceso público.

## Convenciones
- Base URL: relativa al host actual, p.e. `"/api/cupones"`.
- Content-Type:
  - JSON: `application/json`
  - Subida de archivos: `multipart/form-data`
- Respuestas de error comunes:
  - `400`: petición inválida (campos faltantes o formato incorrecto)
  - `401`: no autenticado o no autorizado
  - `404`: recurso no encontrado
  - `409`: conflicto (duplicados)

---

## /api/cupones
Rutas para gestionar cupones.

### GET /api/cupones
- Query:
  - `estado` (opcional): estado del cupón (p.e. `"ACTIVO"`)
  - `comercio` (opcional)
  - `limit` (opcional, por defecto `20`)
- Autenticación: no obligatoria.

Ejemplo `fetch`:
```ts
const res = await fetch('/api/cupones?estado=ACTIVO&limit=10');
const data = await res.json();
```

Ejemplo `curl`:
```bash
curl -sS '/api/cupones?estado=ACTIVO&limit=10'
```

Respuesta típica:
```json
[
  {
    "id": "uuid",
    "nombre": "10% descuento",
    "descripcion": "Aplica en tienda X",
    "comercio": "Tienda X",
    "imagenUrl": "https://.../img.png",
    "puntosRequeridos": 100,
    "estado": "ACTIVO",
    "createdAt": "2025-01-01T00:00:00Z"
  }
]
```

### POST /api/cupones
- Body (JSON):
  - Requeridos: `nombre`, `descripcion`, `comercio`
  - Opcionales: `imagenUrl`, `puntosRequeridos`, `storeId`, `fechaFin`, `qrCode`, `nivelRequerido`, `estado` (`"ACTIVO"` por defecto)
- Autenticación: requiere usuario Supabase.

Ejemplo `fetch`:
```ts
const res = await fetch('/api/cupones', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    nombre: '15% descuento',
    descripcion: 'Válido hasta fin de mes',
    comercio: 'Tienda Y'
  })
});
const created = await res.json();
```

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

