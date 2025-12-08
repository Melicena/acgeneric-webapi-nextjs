# 📦 Resumen de Implementación: Usuarios y Asociaciones

## ✅ Archivos Creados/Modificados

### 1. **Tipos TypeScript** (`lib/types.ts`)
- ✅ Agregado `UserRoles` con constantes para roles
- ✅ Agregado `UserRole` type
- ✅ Agregado `AsociacionModel` interface
- ✅ Actualizado `UsuarioModel` con:
  - Campo `managedAssociations: AsociacionModel[] | null`
  - Tipos más específicos para `comercios` y `comerciosSubs`
  - Campo `token` y tipos mejorados
- ✅ Agregado `AsociacionMapper` con `toDomain` y `toDbInsert`
- ✅ Actualizado `UsuarioMapper` para manejar asociaciones

### 2. **Tipos de Base de Datos** (`lib/supabase/database.types.ts`)
- ✅ Agregada tabla `associations` con:
  - Row, Insert, Update types
  - Relationship con `usuarios`

### 3. **SQL** (`sql/`)
- ✅ `usuarios_y_asociaciones.sql` - Script completo de creación:
  - Actualización de tabla `usuarios`
  - Creación de tabla `associations`
  - Índices para rendimiento
  - Políticas RLS para ambas tablas
  - Triggers para `updated_at`
  - Funciones helper

- ✅ `queries_usuarios_asociaciones.sql` - 15+ queries útiles:
  - JOINs para obtener usuarios con asociaciones
  - Búsquedas y filtros
  - Gestión de comercios en asociaciones
  - Estadísticas y reportes

- ✅ `README_USUARIOS_ASOCIACIONES.md` - Documentación completa

### 4. **Ejemplos de API** (`app/api/`)
- ✅ `usuarios/[id]/route.ts.example` - CRUD de usuarios
- ✅ `associations/route.ts.example` - Listar y crear asociaciones
- ✅ `associations/[id]/route.ts.example` - CRUD de asociaciones individuales

## 📊 Modelo de Datos

### Usuario (UsuarioModel)
```typescript
{
  id: string
  email: string
  displayName: string | null
  avatarUrl: string | null
  rol: 'usuario' | 'negocio' | 'asociacion_admin'
  comercios: string[] | null              // IDs de comercios directos
  comerciosSubs: Record<string, boolean> | null
  token: string | null
  ultimoAcceso: string | null
  createdAt: string
  managedAssociations: AsociacionModel[] | null  // 🆕 Asociaciones que administra
}
```

### Asociación (AsociacionModel)
```typescript
{
  id: string
  nombre: string
  descripcion: string | null
  logoUrl: string | null
  adminUserId: string                     // Usuario administrador
  comerciosIds: string[]                  // IDs de comercios en la asociación
  activa: boolean
  createdAt: string
  updatedAt: string | null
}
```

## 🔐 Seguridad (RLS)

### Tabla `usuarios`
- ✅ Lectura: Pública
- ✅ Inserción: Solo autenticados (auth.uid() = id)
- ✅ Actualización: Solo el propio usuario
- ✅ Eliminación: Solo el propio usuario

### Tabla `associations`
- ✅ Lectura pública: Solo asociaciones activas
- ✅ Lectura completa: Administrador de la asociación
- ✅ Inserción: Usuario autenticado (admin_user_id)
- ✅ Actualización: Solo el administrador
- ✅ Eliminación: Solo el administrador
- ✅ Cascada: Si se elimina un usuario admin, se eliminan sus asociaciones

## 🚀 Pasos para Implementar

### 1. Ejecutar el SQL en Supabase
```bash
# Copiar el contenido de sql/usuarios_y_asociaciones.sql
# Ejecutarlo en el SQL Editor de Supabase
```

### 2. Verificar las Tablas
```sql
-- Ver estructura de usuarios
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'usuarios';

-- Ver estructura de associations
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'associations';
```

### 3. Crear los Endpoints de API
Renombrar los archivos `.example` a `.ts`:
```bash
# Windows PowerShell
mv app/api/usuarios/[id]/route.ts.example app/api/usuarios/[id]/route.ts
mv app/api/associations/route.ts.example app/api/associations/route.ts
mv app/api/associations/[id]/route.ts.example app/api/associations/[id]/route.ts
```

### 4. Probar los Endpoints

#### Obtener usuario con asociaciones:
```bash
GET /api/usuarios/{userId}
```

#### Crear asociación:
```bash
POST /api/associations
Content-Type: application/json

{
  "nombre": "Asociación Centro Comercial",
  "descripcion": "Comercios del centro",
  "comerciosIds": ["comercio-1", "comercio-2"]
}
```

#### Listar asociaciones de un usuario:
```bash
GET /api/associations?adminUserId={userId}
```

## 💡 Casos de Uso

### Caso 1: Usuario Individual con Negocio
```typescript
const usuario = {
  rol: 'negocio',
  comercios: ['mi-tienda-123'],
  managedAssociations: null
}
```

### Caso 2: Administrador de Asociación
```typescript
const admin = {
  rol: 'asociacion_admin',
  comercios: null,
  managedAssociations: [
    {
      nombre: 'Asociación Centro',
      comerciosIds: ['tienda-1', 'tienda-2', 'tienda-3']
    }
  ]
}
```

### Caso 3: Usuario Mixto
```typescript
const mixto = {
  rol: 'asociacion_admin',
  comercios: ['mi-tienda'],           // Su propio negocio
  managedAssociations: [              // Además administra una asociación
    {
      nombre: 'Asociación Regional',
      comerciosIds: ['comercio-a', 'comercio-b']
    }
  ]
}
```

## 🔧 Funciones Helper Disponibles

### 1. `get_user_managed_associations(user_id)`
Obtiene todas las asociaciones que administra un usuario.

### 2. `is_association_admin(user_id)`
Verifica si un usuario es admin de al menos una asociación activa.

### 3. `create_association_and_update_role(...)`
Crea una asociación y actualiza automáticamente el rol del usuario.

## 📝 Queries Útiles

Ver `sql/queries_usuarios_asociaciones.sql` para:
- ✅ Obtener usuario con asociaciones (JOIN)
- ✅ Listar usuarios con conteo de asociaciones
- ✅ Buscar asociaciones por comercio
- ✅ Agregar/remover comercios de asociaciones
- ✅ Transferir administración
- ✅ Estadísticas

## 🎯 Compatibilidad con Kotlin/Android

El modelo TypeScript está 100% alineado con el modelo Kotlin proporcionado:

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

## ⚠️ Notas Importantes

1. **RLS Habilitado**: Todas las operaciones respetan políticas de seguridad
2. **Cascada**: Eliminar usuario admin → elimina sus asociaciones
3. **Índices**: Creados para búsquedas eficientes
4. **Trigger**: `updated_at` se actualiza automáticamente
5. **Validación**: Se evitan duplicados al agregar comercios

## 📚 Archivos de Referencia

- `lib/types.ts` - Tipos TypeScript y mappers
- `lib/supabase/database.types.ts` - Tipos generados de Supabase
- `sql/usuarios_y_asociaciones.sql` - Script de creación
- `sql/queries_usuarios_asociaciones.sql` - Queries útiles
- `sql/README_USUARIOS_ASOCIACIONES.md` - Documentación detallada
- `app/api/usuarios/[id]/route.ts.example` - Ejemplo API usuarios
- `app/api/associations/route.ts.example` - Ejemplo API asociaciones
- `app/api/associations/[id]/route.ts.example` - Ejemplo API asociación individual

## ✨ Próximos Pasos

1. ✅ Ejecutar el SQL en Supabase
2. ✅ Renombrar archivos `.example` a `.ts`
3. ✅ Probar los endpoints
4. ✅ Implementar en la app Android/Kotlin
5. ✅ Crear UI para gestión de asociaciones
