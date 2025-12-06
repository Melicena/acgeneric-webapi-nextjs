# 📋 Guía de Uso de API - Usuarios

## 🔗 Endpoints Disponibles

### **Lista de Usuarios**
```
GET /api/usuarios
```

### **Crear Usuario**
```
POST /api/usuarios
```

### **Obtener Usuario por ID** ⭐ NUEVO
```
GET /api/usuarios/[id]
```

### **Actualizar Usuario por ID** ⭐ NUEVO
```
PUT /api/usuarios/[id]
```

### **Eliminar Usuario por ID** ⭐ NUEVO
```
DELETE /api/usuarios/[id]
```

---

## 📝 Ejemplos de Uso

### 1. Obtener Usuario por ID

**URL**: `GET /api/usuarios/{uuid}`

**Ejemplo**:
```javascript
// Con fetch
const response = await fetch('http://localhost:3000/api/usuarios/123e4567-e89b-12d3-a456-426614174000')
const data = await response.json()

console.log(data)
// { data: { id: '123...', email: 'user@example.com', nombre: 'Juan' } }
```

**Respuestas**:

✅ **Éxito (200)**:
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "created_at": "2025-12-03T18:00:00.000Z",
    "email": "usuario@ejemplo.com",
    "nombre": "Juan Pérez"
  }
}
```

❌ **Usuario no encontrado (404)**:
```json
{
  "error": "Usuario no encontrado"
}
```

❌ **Error del servidor (500)**:
```json
{
  "error": "Error message"
}
```

---

### 2. Obtener Lista de Usuarios

**URL**: `GET /api/usuarios?limit=10&offset=0`

**Parámetros**:
- `limit` (opcional): Número de resultados (default: 10)
- `offset` (opcional): Desde qué registro empezar (default: 0)

**Ejemplo**:
```javascript
// Obtener los primeros 20 usuarios
const response = await fetch('http://localhost:3000/api/usuarios?limit=20')
const data = await response.json()

console.log(data)
// { data: [...], count: 100, limit: 20, offset: 0 }
```

**Respuesta**:
```json
{
  "data": [
    {
      "id": "123...",
      "email": "user1@example.com",
      "nombre": "Usuario 1",
      "created_at": "2025-12-03T18:00:00.000Z"
    },
    {
      "id": "456...",
      "email": "user2@example.com",
      "nombre": "Usuario 2",
      "created_at": "2025-12-03T17:00:00.000Z"
    }
  ],
  "count": 100,
  "limit": 20,
  "offset": 0
}
```

---

### 3. Crear Usuario

**URL**: `POST /api/usuarios`

**Body**:
```json
{
  "email": "nuevo@ejemplo.com",
  "nombre": "Nuevo Usuario"  // opcional
}
```

**Ejemplo**:
```javascript
const response = await fetch('http://localhost:3000/api/usuarios', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'nuevo@ejemplo.com',
    nombre: 'Nuevo Usuario'
  })
})

const data = await response.json()
console.log(data)
```

**Respuestas**:

✅ **Creado (201)**:
```json
{
  "data": {
    "id": "new-uuid-here",
    "email": "nuevo@ejemplo.com",
    "nombre": "Nuevo Usuario",
    "created_at": "2025-12-03T19:00:00.000Z"
  }
}
```

❌ **Email requerido (400)**:
```json
{
  "error": "El email es requerido"
}
```

❌ **Email inválido (400)**:
```json
{
  "error": "El email no tiene un formato válido"
}
```

❌ **Email duplicado (409)**:
```json
{
  "error": "El email ya está registrado"
}
```

---

### 4. Actualizar Usuario por ID

**URL**: `PUT /api/usuarios/{uuid}`

**Body**:
```json
{
  "email": "actualizado@ejemplo.com",
  "nombre": "Nombre Actualizado"
}
```

**Ejemplo**:
```javascript
const userId = '123e4567-e89b-12d3-a456-426614174000'

const response = await fetch(`http://localhost:3000/api/usuarios/${userId}`, {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'actualizado@ejemplo.com',
    nombre: 'Nombre Actualizado'
  })
})

const data = await response.json()
console.log(data)
```

**Respuesta**:
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "actualizado@ejemplo.com",
    "nombre": "Nombre Actualizado",
    "created_at": "2025-12-03T18:00:00.000Z"
  }
}
```

---

### 5. Eliminar Usuario por ID

**URL**: `DELETE /api/usuarios/{uuid}`

**Ejemplo**:
```javascript
const userId = '123e4567-e89b-12d3-a456-426614174000'

const response = await fetch(`http://localhost:3000/api/usuarios/${userId}`, {
  method: 'DELETE'
})

const data = await response.json()
console.log(data)
```

**Respuesta**:
```json
{
  "message": "Usuario eliminado correctamente"
}
```

---

## 🧪 Probar con cURL

### Obtener usuario por ID
```bash
curl http://localhost:3000/api/usuarios/123e4567-e89b-12d3-a456-426614174000
```

### Listar usuarios
```bash
curl "http://localhost:3000/api/usuarios?limit=5"
```

### Crear usuario
```bash
curl -X POST http://localhost:3000/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{"email":"nuevo@ejemplo.com","nombre":"Nuevo Usuario"}'
```

### Actualizar usuario
```bash
curl -X PUT http://localhost:3000/api/usuarios/123e4567-e89b-12d3-a456-426614174000 \
  -H "Content-Type: application/json" \
  -d '{"email":"actualizado@ejemplo.com","nombre":"Nombre Actualizado"}'
```

### Eliminar usuario
```bash
curl -X DELETE http://localhost:3000/api/usuarios/123e4567-e89b-12d3-a456-426614174000
```

---

## 🔍 Códigos de Estado HTTP

| Código | Significado | Cuándo se usa |
|--------|-------------|---------------|
| **200** | OK | Operación exitosa (GET, PUT) |
| **201** | Created | Usuario creado exitosamente |
| **400** | Bad Request | Datos inválidos o faltantes |
| **404** | Not Found | Usuario no encontrado |
| **409** | Conflict | Email duplicado |
| **500** | Server Error | Error en el servidor |

---

## 💡 Ejemplos con React/Next.js

### Hook personalizado para obtener usuario
```tsx
'use client'

import { useEffect, useState } from 'react'

export function useUsuario(id: string) {
  const [usuario, setUsuario] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchUsuario() {
      try {
        const response = await fetch(`/api/usuarios/${id}`)
        const result = await response.json()
        
        if (response.ok) {
          setUsuario(result.data)
        } else {
          setError(result.error)
        }
      } catch (err) {
        setError('Error al cargar usuario')
      } finally {
        setLoading(false)
      }
    }

    if (id) {
      fetchUsuario()
    }
  }, [id])

  return { usuario, loading, error }
}
```

### Componente de perfil de usuario
```tsx
'use client'

import { useUsuario } from '@/hooks/useUsuario'

export default function PerfilUsuario({ userId }: { userId: string }) {
  const { usuario, loading, error } = useUsuario(userId)

  if (loading) return <div>Cargando...</div>
  if (error) return <div>Error: {error}</div>
  if (!usuario) return <div>Usuario no encontrado</div>

  return (
    <div>
      <h2>{usuario.nombre}</h2>
      <p>{usuario.email}</p>
      <p>Creado: {new Date(usuario.created_at).toLocaleDateString()}</p>
    </div>
  )
}
```

---

## 📚 Patrones REST Implementados

Esta API sigue los estándares REST:

| Operación | Método | URL |
|-----------|--------|-----|
| **Listar** | GET | `/api/usuarios` |
| **Obtener** | GET | `/api/usuarios/{id}` |
| **Crear** | POST | `/api/usuarios` |
| **Actualizar** | PUT | `/api/usuarios/{id}` |
| **Eliminar** | DELETE | `/api/usuarios/{id}` |

---

## ⚠️ Nota Importante

Para que estos endpoints funcionen, asegúrate de:

1. ✅ Tener configurado el archivo `.env.local` con tus credenciales de Supabase
2. ✅ Haber creado la tabla `usuarios` en Supabase
3. ✅ Tener las políticas RLS configuradas correctamente
4. ✅ El servidor de desarrollo esté corriendo (`npm run dev`)

---

## 🔗 Enlaces Útiles

- Ver ejemplos visuales: http://localhost:3000/examples
- Documentación de Supabase: [docs.supabase.com](https://supabase.com/docs)
- Next.js API Routes: [nextjs.org/docs/app/building-your-application/routing/route-handlers](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)

---

¡Disfruta de tu API REST con Supabase! 🚀
