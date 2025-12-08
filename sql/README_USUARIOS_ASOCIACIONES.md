# Usuarios y Asociaciones - Documentación

## 📋 Descripción General

Este módulo implementa el sistema de usuarios y asociaciones de comercios, permitiendo que:
- **Usuarios individuales** puedan gestionar comercios directamente
- **Administradores de asociaciones** puedan gestionar múltiples comercios bajo una asociación

## 🏗️ Estructura de Datos

### Modelo de Usuario (`UsuarioModel`)

```typescript
interface UsuarioModel {
    id: string                                    // UUID del usuario
    email: string                                 // Email del usuario
    displayName: string | null                    // Nombre para mostrar
    avatarUrl: string | null                      // URL del avatar
    rol: UserRole                                 // Rol: 'usuario', 'negocio', 'asociacion_admin'
    comercios: string[] | null                    // IDs de comercios que administra directamente
    comerciosSubs: Record<string, boolean> | null // Suscripciones a comercios
    token: string | null                          // Token de autenticación
    ultimoAcceso: string | null                   // Fecha del último acceso
    createdAt: string                             // Fecha de creación
    managedAssociations: AsociacionModel[] | null // Asociaciones que administra
}
```

### Modelo de Asociación (`AsociacionModel`)

```typescript
interface AsociacionModel {
    id: string              // UUID de la asociación
    nombre: string          // Nombre de la asociación
    descripcion: string | null
    logoUrl: string | null
    adminUserId: string     // ID del usuario administrador
    comerciosIds: string[]  // Array de IDs de comercios
    activa: boolean         // Si la asociación está activa
    createdAt: string
    updatedAt: string | null
}
```

### Roles de Usuario

```typescript
const UserRoles = {
    USUARIO: 'usuario',              // Usuario regular
    NEGOCIO: 'negocio',              // Usuario que gestiona un negocio
    ASOCIACION_ADMIN: 'asociacion_admin' // Administrador de asociación
}
```

## 🗄️ Estructura de Base de Datos

### Tabla `usuarios`

```sql
CREATE TABLE usuarios (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    rol TEXT DEFAULT 'usuario',
    comercios TEXT[],                -- Array de IDs de comercios
    comercios_subs JSONB,            -- { "comercio_id": boolean }
    token TEXT,
    ultimo_acceso TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Tabla `associations`

```sql
CREATE TABLE associations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    logo_url TEXT,
    admin_user_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    comercios_ids TEXT[] NOT NULL DEFAULT '{}',
    activa BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);
```

## 🔐 Políticas de Seguridad (RLS)

### Usuarios

- ✅ **Lectura**: Pública (cualquiera puede leer)
- ✅ **Inserción**: Solo usuarios autenticados (auth.uid() = id)
- ✅ **Actualización**: Solo el propio usuario
- ✅ **Eliminación**: Solo el propio usuario

### Asociaciones

- ✅ **Lectura pública**: Solo asociaciones activas
- ✅ **Lectura completa**: Administrador de la asociación
- ✅ **Inserción**: Usuario autenticado (debe ser admin_user_id)
- ✅ **Actualización**: Solo el administrador
- ✅ **Eliminación**: Solo el administrador

## 📝 Instalación

### 1. Ejecutar el SQL en Supabase

```bash
# Copiar el contenido de sql/usuarios_y_asociaciones.sql
# y ejecutarlo en el SQL Editor de Supabase
```

### 2. Actualizar los tipos de TypeScript

Los tipos ya están actualizados en `lib/types.ts`. Si necesitas regenerar los tipos de Supabase:

```bash
npx supabase gen types typescript --project-id YOUR_PROJECT_ID > lib/supabase/database.types.ts
```

## 🚀 Uso en la Aplicación

### Obtener un usuario con sus asociaciones

```typescript
import { createClient } from '@/lib/supabase/server'
import { UsuarioMapper, AsociacionMapper } from '@/lib/types'

async function getUserWithAssociations(userId: string) {
    const supabase = createClient()
    
    // Obtener el usuario
    const { data: usuario, error: userError } = await supabase
        .from('usuarios')
        .select('*')
        .eq('id', userId)
        .single()
    
    if (userError || !usuario) {
        throw new Error('Usuario no encontrado')
    }
    
    // Obtener las asociaciones que administra
    const { data: associations, error: assocError } = await supabase
        .from('associations')
        .select('*')
        .eq('admin_user_id', userId)
    
    // Mapear a los modelos de dominio
    const managedAssociations = associations?.map(AsociacionMapper.toDomain) || []
    const userModel = UsuarioMapper.toDomain(usuario, managedAssociations)
    
    return userModel
}
```

### Crear una asociación

```typescript
async function createAssociation(data: {
    nombre: string
    descripcion?: string
    logoUrl?: string
    adminUserId: string
    comerciosIds: string[]
}) {
    const supabase = createClient()
    
    const { data: association, error } = await supabase
        .from('associations')
        .insert({
            nombre: data.nombre,
            descripcion: data.descripcion,
            logo_url: data.logoUrl,
            admin_user_id: data.adminUserId,
            comercios_ids: data.comerciosIds,
            activa: true
        })
        .select()
        .single()
    
    if (error) throw error
    
    // Actualizar el rol del usuario a asociacion_admin
    await supabase
        .from('usuarios')
        .update({ rol: 'asociacion_admin' })
        .eq('id', data.adminUserId)
    
    return AsociacionMapper.toDomain(association)
}
```

### Verificar si un usuario es admin de asociación

```typescript
function isAssociationAdmin(user: UsuarioModel): boolean {
    return user.managedAssociations !== null && 
           user.managedAssociations.length > 0
}

// O usando el rol
function isAssociationAdminByRole(user: UsuarioModel): boolean {
    return user.rol === UserRoles.ASOCIACION_ADMIN
}
```

### Obtener todos los comercios que puede administrar un usuario

```typescript
async function getUserManagedComercios(userId: string) {
    const supabase = createClient()
    
    const { data } = await supabase.rpc('get_user_managed_comercios', {
        user_id: userId
    })
    
    return data || []
}
```

## 📊 Queries Útiles

Ver el archivo `sql/queries_usuarios_asociaciones.sql` para queries útiles como:

- Obtener usuario con asociaciones (JOIN)
- Listar usuarios con conteo de asociaciones
- Buscar asociaciones por comercio
- Agregar/remover comercios de asociaciones
- Transferir administración de asociaciones
- Estadísticas de asociaciones

## 🔧 Funciones Helper

### `get_user_managed_associations(user_id UUID)`

Retorna todas las asociaciones administradas por un usuario.

```sql
SELECT * FROM get_user_managed_associations('USER_ID_AQUI');
```

### `is_association_admin(user_id UUID)`

Verifica si un usuario es administrador de al menos una asociación activa.

```sql
SELECT is_association_admin('USER_ID_AQUI');
```

### `create_association_and_update_role(...)`

Crea una asociación y actualiza automáticamente el rol del usuario.

```sql
SELECT create_association_and_update_role(
    'Nombre Asociación',
    'Descripción',
    'https://logo.url',
    'USER_ID',
    ARRAY['comercio1', 'comercio2']
);
```

## 🎯 Casos de Uso

### 1. Usuario Individual con Negocio

```typescript
const usuario = {
    rol: UserRoles.NEGOCIO,
    comercios: ['comercio-123'],
    managedAssociations: null
}
```

### 2. Administrador de Asociación

```typescript
const adminAsociacion = {
    rol: UserRoles.ASOCIACION_ADMIN,
    comercios: null,
    managedAssociations: [
        {
            id: 'assoc-1',
            nombre: 'Asociación Centro',
            comerciosIds: ['comercio-1', 'comercio-2', 'comercio-3']
        }
    ]
}
```

### 3. Usuario Mixto (Negocio + Asociación)

```typescript
const usuarioMixto = {
    rol: UserRoles.ASOCIACION_ADMIN,
    comercios: ['mi-comercio'],
    managedAssociations: [
        {
            id: 'assoc-1',
            nombre: 'Mi Asociación',
            comerciosIds: ['comercio-a', 'comercio-b']
        }
    ]
}
```

## 🔄 Sincronización con Kotlin/Android

El modelo TypeScript está alineado con el modelo Kotlin:

```kotlin
@Serializable
data class UsuarioModel(
    val id: String,
    val email: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val comercios: List<String>? = null,
    @SerialName("comercios_subs") val comerciosSubs: Map<String, Boolean>? = null,
    @SerialName("display_name") val displayName: String? = null,
    val rol: String,
    val token: String? = null,
    @SerialName("ultimo_acceso") val ultimoAcceso: String? = null,
    @SerialName("managed_associations") val asociacionesAdministradas: List<AsociacionModel>? = null
)
```

## 📚 Recursos Adicionales

- `lib/types.ts` - Definiciones de tipos TypeScript
- `sql/usuarios_y_asociaciones.sql` - SQL para crear tablas y políticas
- `sql/queries_usuarios_asociaciones.sql` - Queries útiles y ejemplos

## ⚠️ Notas Importantes

1. **RLS está habilitado**: Todas las operaciones respetan las políticas de seguridad
2. **Cascada en DELETE**: Si se elimina un usuario admin, se eliminan sus asociaciones
3. **Índices creados**: Para mejorar el rendimiento en búsquedas frecuentes
4. **Trigger automático**: `updated_at` se actualiza automáticamente en associations
5. **Validación de duplicados**: Al agregar comercios a asociaciones se evitan duplicados
