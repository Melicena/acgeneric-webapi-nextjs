# 🏗️ Arquitectura del Sistema: Usuarios y Asociaciones

## 📊 Diagrama de Relaciones

```
┌─────────────────────────────────────────────────────────────────┐
│                         USUARIOS                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ id: UUID (PK)                                            │   │
│  │ email: TEXT                                              │   │
│  │ display_name: TEXT                                       │   │
│  │ avatar_url: TEXT                                         │   │
│  │ rol: TEXT ('usuario', 'negocio', 'asociacion_admin')    │   │
│  │ comercios: TEXT[] (IDs de comercios directos)           │   │
│  │ comercios_subs: JSONB                                    │   │
│  │ token: TEXT                                              │   │
│  │ ultimo_acceso: TIMESTAMP                                 │   │
│  │ created_at: TIMESTAMP                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ admin_user_id (FK)
                              │ ON DELETE CASCADE
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ASSOCIATIONS                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ id: UUID (PK)                                            │   │
│  │ nombre: TEXT                                             │   │
│  │ descripcion: TEXT                                        │   │
│  │ logo_url: TEXT                                           │   │
│  │ admin_user_id: UUID (FK → usuarios.id)                  │   │
│  │ comercios_ids: TEXT[] (IDs de comercios en asociación)  │   │
│  │ activa: BOOLEAN                                          │   │
│  │ created_at: TIMESTAMP                                    │   │
│  │ updated_at: TIMESTAMP                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Datos

### 1. Usuario Individual con Negocio

```
┌──────────────┐
│   Usuario    │
│ rol: negocio │
└──────┬───────┘
       │
       │ comercios: ['comercio-123']
       │
       ▼
┌──────────────┐
│  Comercio    │
│  comercio-123│
└──────────────┘
```

### 2. Administrador de Asociación

```
┌─────────────────────────┐
│       Usuario           │
│ rol: asociacion_admin   │
└───────────┬─────────────┘
            │
            │ admin_user_id
            │
            ▼
┌───────────────────────────────────┐
│        Asociación                 │
│  nombre: "Asociación Centro"      │
│  comercios_ids: ['c1','c2','c3']  │
└───────────┬───────────────────────┘
            │
            ├──────┬──────┬──────┐
            ▼      ▼      ▼      ▼
         ┌────┐ ┌────┐ ┌────┐ ┌────┐
         │ C1 │ │ C2 │ │ C3 │ │... │
         └────┘ └────┘ └────┘ └────┘
```

### 3. Usuario Mixto (Negocio + Asociación)

```
┌─────────────────────────┐
│       Usuario           │
│ rol: asociacion_admin   │
│ comercios: ['mi-tienda']│
└───────┬─────────────────┘
        │
        ├─────────────────────┐
        │                     │
        │ (directo)           │ (admin_user_id)
        ▼                     ▼
   ┌─────────┐      ┌──────────────────┐
   │Mi Tienda│      │   Asociación     │
   └─────────┘      │ comercios_ids:   │
                    │ ['c1','c2','c3'] │
                    └────────┬─────────┘
                             │
                    ┌────────┼────────┐
                    ▼        ▼        ▼
                  ┌───┐    ┌───┐    ┌───┐
                  │C1 │    │C2 │    │C3 │
                  └───┘    └───┘    └───┘
```

## 🔐 Políticas de Seguridad (RLS)

### Tabla: usuarios

```
┌─────────────────────────────────────────────────────────┐
│                    USUARIOS - RLS                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  SELECT (Lectura)                                        │
│  ✅ Pública: true                                        │
│  → Cualquiera puede leer usuarios                       │
│                                                          │
│  INSERT (Inserción)                                      │
│  ✅ Autenticado: auth.uid() = id                        │
│  → Solo usuarios autenticados pueden crear su perfil    │
│                                                          │
│  UPDATE (Actualización)                                  │
│  ✅ Propio usuario: auth.uid() = id                     │
│  → Solo puedes actualizar tu propio perfil              │
│                                                          │
│  DELETE (Eliminación)                                    │
│  ✅ Propio usuario: auth.uid() = id                     │
│  → Solo puedes eliminar tu propio perfil                │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Tabla: associations

```
┌─────────────────────────────────────────────────────────┐
│                 ASSOCIATIONS - RLS                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  SELECT (Lectura)                                        │
│  ✅ Pública (activas): activa = true                    │
│  ✅ Admin (todas): auth.uid() = admin_user_id           │
│  → Todos ven activas, admin ve todas sus asociaciones   │
│                                                          │
│  INSERT (Inserción)                                      │
│  ✅ Autenticado: auth.uid() = admin_user_id             │
│  → Solo puedes crear asociaciones donde eres admin      │
│                                                          │
│  UPDATE (Actualización)                                  │
│  ✅ Admin: auth.uid() = admin_user_id                   │
│  → Solo el admin puede actualizar la asociación         │
│                                                          │
│  DELETE (Eliminación)                                    │
│  ✅ Admin: auth.uid() = admin_user_id                   │
│  → Solo el admin puede eliminar la asociación           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Operaciones

### Crear Asociación

```
1. Usuario autenticado hace POST /api/associations
   ↓
2. Backend valida autenticación
   ↓
3. Se crea registro en tabla associations
   ↓
4. Se actualiza rol del usuario a 'asociacion_admin'
   ↓
5. Se retorna AsociacionModel creada
```

### Obtener Usuario con Asociaciones

```
1. Cliente hace GET /api/usuarios/{id}
   ↓
2. Backend obtiene usuario de tabla usuarios
   ↓
3. Backend hace JOIN con associations
   WHERE admin_user_id = usuario.id
   ↓
4. Se mapean datos a UsuarioModel con managedAssociations
   ↓
5. Se retorna usuario completo con asociaciones
```

### Agregar Comercio a Asociación

```
1. Admin hace POST /api/associations/{id}/comercios
   Body: { comercioId: 'nuevo-comercio' }
   ↓
2. Backend valida que auth.uid() = admin_user_id
   ↓
3. Backend verifica que comercio no esté duplicado
   ↓
4. Se actualiza array comercios_ids
   comercios_ids = [...comercios_ids, 'nuevo-comercio']
   ↓
5. Trigger actualiza updated_at automáticamente
   ↓
6. Se retorna AsociacionModel actualizada
```

## 📦 Capas de la Aplicación

```
┌─────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Android    │  │   Next.js    │  │   Web App    │  │
│  │   (Kotlin)   │  │   (React)    │  │  (TypeScript)│  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ HTTP/REST
                            │
┌───────────────────────────▼─────────────────────────────┐
│                    CAPA DE API (Next.js)                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │  /api/usuarios/[id]                              │   │
│  │  /api/associations                               │   │
│  │  /api/associations/[id]                          │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Supabase Client
                            │
┌───────────────────────────▼─────────────────────────────┐
│                  CAPA DE DOMINIO (Types)                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │  UsuarioModel, AsociacionModel                   │   │
│  │  UsuarioMapper, AsociacionMapper                 │   │
│  │  UserRoles, UserRole                             │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ SQL Queries
                            │
┌───────────────────────────▼─────────────────────────────┐
│                 CAPA DE DATOS (Supabase)                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │  PostgreSQL Database                             │   │
│  │  - usuarios (tabla)                              │   │
│  │  - associations (tabla)                          │   │
│  │  - RLS Policies                                  │   │
│  │  - Triggers                                      │   │
│  │  - Functions                                     │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Casos de Uso Detallados

### Caso 1: Crear Primera Asociación

```
ACTOR: Usuario con negocio
OBJETIVO: Crear asociación para gestionar múltiples comercios

FLUJO:
1. Usuario tiene rol 'negocio'
2. Usuario crea asociación con comercios ['c1', 'c2', 'c3']
3. Sistema crea registro en associations
4. Sistema actualiza rol a 'asociacion_admin'
5. Usuario ahora puede gestionar:
   - Su comercio directo (si lo tiene)
   - Los 3 comercios de la asociación

RESULTADO:
{
  rol: 'asociacion_admin',
  comercios: ['mi-negocio'],
  managedAssociations: [
    {
      nombre: 'Mi Asociación',
      comerciosIds: ['c1', 'c2', 'c3']
    }
  ]
}
```

### Caso 2: Verificar Permisos de Administración

```
ACTOR: Sistema
OBJETIVO: Verificar si usuario puede administrar un comercio

FLUJO:
1. Usuario intenta editar comercio 'c2'
2. Sistema verifica:
   a) ¿Está en usuario.comercios? → NO
   b) ¿Está en alguna asociación activa? → SÍ
3. Sistema permite la operación

LÓGICA:
function canManageComercio(userId, comercioId) {
  // Verificar comercios directos
  if (usuario.comercios.includes(comercioId)) return true
  
  // Verificar asociaciones
  return usuario.managedAssociations.some(assoc => 
    assoc.activa && assoc.comerciosIds.includes(comercioId)
  )
}
```

### Caso 3: Desactivar Asociación

```
ACTOR: Administrador de asociación
OBJETIVO: Desactivar asociación temporalmente

FLUJO:
1. Admin hace PATCH /api/associations/{id}
   Body: { activa: false }
2. Sistema valida que auth.uid() = admin_user_id
3. Sistema actualiza activa = false
4. Trigger actualiza updated_at
5. Asociación ya no aparece en listados públicos
6. Admin aún puede verla y reactivarla

RESULTADO:
- Asociación oculta para usuarios normales
- Admin mantiene acceso completo
- Comercios no se eliminan, solo se ocultan
```

## 📈 Escalabilidad

### Índices Creados

```sql
-- Búsqueda rápida por administrador
CREATE INDEX idx_associations_admin_user_id 
ON associations(admin_user_id);

-- Filtrado por estado
CREATE INDEX idx_associations_activa 
ON associations(activa);

-- Búsqueda en array de comercios (GIN)
CREATE INDEX idx_associations_comercios_ids 
ON associations USING GIN(comercios_ids);
```

### Optimizaciones

1. **Carga Lazy de Asociaciones**
   - Solo cargar cuando sea necesario
   - Usar parámetro `?includeAssociations=true`

2. **Caché de Permisos**
   - Cachear resultado de `canManageComercio()`
   - Invalidar al actualizar asociaciones

3. **Paginación**
   - Limitar resultados en listados
   - Usar cursor-based pagination

## 🔧 Mantenimiento

### Limpieza de Datos

```sql
-- Eliminar asociaciones inactivas antiguas (>1 año)
DELETE FROM associations
WHERE activa = false
AND updated_at < NOW() - INTERVAL '1 year';

-- Actualizar rol de usuarios sin asociaciones
UPDATE usuarios
SET rol = 'negocio'
WHERE rol = 'asociacion_admin'
AND NOT EXISTS (
  SELECT 1 FROM associations 
  WHERE admin_user_id = usuarios.id
);
```

### Monitoreo

```sql
-- Estadísticas de uso
SELECT 
  COUNT(*) as total_asociaciones,
  AVG(array_length(comercios_ids, 1)) as promedio_comercios,
  COUNT(DISTINCT admin_user_id) as total_admins
FROM associations
WHERE activa = true;
```

---

**Última actualización**: 2025-12-08
**Versión**: 1.0.0
