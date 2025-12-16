# 🗄️ Database - ACGeneric

Esta carpeta contiene todos los scripts SQL para crear y configurar la base de datos PostgreSQL de ACGeneric en Supabase.

---

## 📋 Contenido

### Scripts de Tablas (en orden de ejecución)

| Archivo | Tabla | Descripción | Requisitos |
|---------|-------|-------------|------------|
| `00_master_setup.sql` | - | **Script maestro** que ejecuta todo en orden | ⭐ Ejecutar este primero |
| `01_usuarios.sql` | `usuarios` | Usuarios de la aplicación (clientes, negocios, admins) | RF-001, RF-003 |
| `02_comercios.sql` | `comercios` | Negocios/comercios con ubicación PostGIS | RF-007, RF-020 |
| `03_ofertas.sql` | `ofertas` | Ofertas/promociones publicadas | RF-030, RF-020 |
| `04_cupones.sql` | `cupones` | Cupones guardados y sistema QR | RF-023, RF-031 |
| `05_associations.sql` | `associations` | Asociaciones de comercios | RF-060 |
| `06_association_members.sql` | `association_members` | Membresías y vinculaciones | RF-061 |

### Scripts Adicionales (en carpeta raíz)

| Archivo | Descripción |
|---------|-------------|
| `../database_trigger_handle_new_user.sql` | Trigger para crear usuario en `usuarios` al registrarse |
| `../database_postgis_setup.sql` | Configuración completa de PostGIS |

---

## 🚀 Instalación Rápida

### Opción 1: Script Maestro (Recomendado)

1. Abrir **Supabase Dashboard** → **SQL Editor**
2. Copiar y pegar el contenido de `00_master_setup.sql`
3. Ejecutar
4. Verificar que no hay errores

### Opción 2: Manual (Paso a Paso)

Ejecutar en este orden:

```sql
-- 1. Habilitar extensiones
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Ejecutar scripts en orden
\i 01_usuarios.sql
\i 02_comercios.sql
\i 03_ofertas.sql
\i 04_cupones.sql
\i 05_associations.sql
\i 06_association_members.sql

-- 3. Configurar triggers
\i ../database_trigger_handle_new_user.sql
\i ../database_postgis_setup.sql
```

---

## 📊 Estructura de la Base de Datos

### Diagrama ER Simplificado

```
auth.users (Supabase Auth)
    ↓ (trigger)
usuarios ──────┐
    ↓          │
comercios ─────┼──→ ofertas ──→ cupones
    ↓          │       ↑          ↑
    │          │       │          │
    │          └───────┴──────────┘
    ↓
association_members ──→ associations
```

### Relaciones Principales

- **usuarios** ← `auth.users` (trigger automático)
- **comercios** → `usuarios` (owner_id)
- **ofertas** → `comercios` (comercio)
- **cupones** → `ofertas` + `usuarios` + `comercios`
- **associations** → `usuarios` (admin_user_id)
- **association_members** → `associations` + `comercios`

---

## 🔒 Row Level Security (RLS)

Todas las tablas tienen **RLS habilitado** con políticas específicas:

### usuarios
- ✅ Usuarios ven su propio perfil
- ✅ Usuarios actualizan su propio perfil
- ✅ Admins ven todos los usuarios

### comercios
- ✅ Comercios aprobados son públicos
- ✅ Dueños ven y gestionan sus comercios
- ✅ Admins ven y moderan todos

### ofertas
- ✅ Ofertas activas son públicas
- ✅ Dueños gestionan sus ofertas
- ✅ Solo comercios aprobados pueden crear ofertas

### cupones
- ✅ Usuarios ven solo sus cupones
- ✅ Dueños de comercios ven cupones de sus ofertas
- ✅ Dueños pueden canjear cupones

### associations
- ✅ Admins ven y gestionan sus asociaciones
- ✅ Miembros ven su asociación

### association_members
- ✅ Admins gestionan membresías
- ✅ Dueños ven y responden invitaciones

---

## 🗺️ PostGIS - Búsquedas Geoespaciales

### Columna `location` en `comercios`

```sql
location GEOGRAPHY(Point, 4326)  -- GPS estándar (WGS 84)
```

### Funciones Disponibles

#### 1. Buscar comercios cercanos
```sql
SELECT * FROM buscar_comercios_cercanos(
  40.4168,  -- latitud
  -3.7038,  -- longitud
  5000,     -- radio en metros
  50        -- límite de resultados
);
```

#### 2. Buscar ofertas cercanas
```sql
SELECT * FROM buscar_ofertas_cercanas(
  40.4168,        -- latitud
  -3.7038,        -- longitud
  10000,          -- radio en metros
  'Restaurante',  -- categoría (NULL = todas)
  100             -- límite
);
```

### Índice GIST

```sql
CREATE INDEX idx_comercios_location ON comercios USING GIST (location);
```

**Rendimiento**: Búsqueda en 10,000 comercios ~50-100ms

---

## 🔑 Funciones Helper Principales

### Usuarios
- `get_usuario_by_id(user_id)` - Obtener usuario
- `is_admin(user_id)` - Verificar si es admin
- `is_business_owner(user_id)` - Verificar si es dueño de negocio

### Comercios
- `buscar_comercios_cercanos(...)` - Búsqueda geoespacial
- `is_comercio_approved(comercio_id)` - Verificar aprobación
- `get_comercios_by_owner(owner_id)` - Comercios de un usuario

### Ofertas
- `buscar_ofertas_cercanas(...)` - Búsqueda geoespacial con filtros
- `increment_view_count(oferta_id)` - Incrementar visualizaciones
- `get_oferta_stats(oferta_id)` - Estadísticas de oferta

### Cupones (CORE - RF-031)
- `generate_qr_token(cupon_id)` - Generar token temporal para QR
- `redeem_cupon(hash, token, redeemer_id)` - Validar y canjear cupón
- `expire_old_cupones()` - Marcar cupones expirados (cron job)

### Asociaciones
- `has_active_subscription(association_id)` - Verificar suscripción
- `can_add_member(association_id)` - Verificar límite de miembros
- `get_association_stats(association_id)` - Estadísticas agregadas (RF-063)

### Membresías
- `invite_business_to_association(...)` - Invitar comercio
- `accept_invitation(token)` - Aceptar invitación
- `reject_invitation(token)` - Rechazar invitación
- `get_association_members(association_id)` - Listar miembros

---

## 🧪 Testing

### Verificar Instalación

```sql
-- Verificar que todas las tablas existen
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Verificar RLS habilitado
SELECT tablename, rowsecurity 
FROM pg_tables pt
JOIN pg_class pc ON pt.tablename = pc.relname
WHERE schemaname = 'public';

-- Verificar PostGIS
SELECT PostGIS_Version();

-- Listar todas las políticas RLS
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

### Datos de Prueba

Ver sección comentada al final de `00_master_setup.sql` para insertar comercios de ejemplo en Madrid.

---

## 📝 Triggers Automáticos

### Tabla `usuarios`
- ✅ `handle_new_user()` - Crea usuario al registrarse en auth.users
- ✅ `update_updated_at` - Actualiza timestamp

### Tabla `comercios`
- ✅ `sync_comercio_location()` - Sincroniza `location` ↔ `lat`/`long`
- ✅ `update_updated_at` - Actualiza timestamp

### Tabla `ofertas`
- ✅ `update_updated_at` - Actualiza timestamp

### Tabla `cupones`
- ✅ `generate_cupon_qr_hash()` - Genera hash único para QR
- ✅ `mark_expired_cupones()` - Marca como expirado si fecha_fin pasó
- ✅ `update_updated_at` - Actualiza timestamp

### Tabla `associations`
- ✅ `set_association_max_members()` - Establece límite según tier
- ✅ `update_updated_at` - Actualiza timestamp

### Tabla `association_members`
- ✅ `set_joined_at()` - Establece fecha al activar membresía
- ✅ `generate_invitation_token()` - Genera token de invitación
- ✅ `update_updated_at` - Actualiza timestamp

---

## 🔄 Cron Jobs Recomendados

### Marcar cupones expirados (cada hora)
```sql
SELECT expire_old_cupones();
```

### Limpiar tokens QR expirados (diario)
```sql
UPDATE cupones 
SET qr_token = NULL, qr_token_expires_at = NULL
WHERE qr_token_expires_at < NOW();
```

### Verificar suscripciones expiradas (diario)
```sql
UPDATE associations
SET subscription_status = 'inactive'
WHERE subscription_status = 'active'
  AND subscription_end_date < NOW();
```

---

## 📚 Referencias

- [Documento SRS](../Plantilla%20de%20Documento%20de%20Requisitos%20de%20Software%20(SRS).md) - Especificación completa
- [PostGIS Documentation](https://postgis.net/docs/) - Funciones geoespaciales
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security) - Row Level Security
- [PostgreSQL Triggers](https://www.postgresql.org/docs/current/triggers.html) - Documentación de triggers

---

## ⚠️ Notas Importantes

1. **Orden de ejecución**: Los scripts deben ejecutarse en orden debido a dependencias (foreign keys)
2. **PostGIS requerido**: Habilitar extensión antes de crear tabla `comercios`
3. **RLS siempre activo**: Todas las tablas tienen RLS habilitado por seguridad
4. **Triggers automáticos**: No requieren intervención manual
5. **Funciones SECURITY DEFINER**: Ejecutan con permisos elevados, usar con cuidado

---

## 🚨 Troubleshooting

### Error: "extension postgis does not exist"
**Solución**: Habilitar PostGIS en Supabase Dashboard → Database → Extensions

### Error: "relation already exists"
**Solución**: Las tablas ya existen. Usar `DROP TABLE IF EXISTS` o ejecutar en base de datos limpia

### Error: "permission denied for schema public"
**Solución**: Verificar que el usuario tiene permisos de creación en schema public

### RLS bloquea todas las consultas
**Solución**: Verificar que las políticas RLS están correctamente configuradas y que `auth.uid()` retorna el UUID correcto

---

## ✅ Checklist de Instalación

- [ ] PostGIS habilitado
- [ ] pg_trgm habilitado
- [ ] Script `00_master_setup.sql` ejecutado sin errores
- [ ] Todas las 6 tablas creadas
- [ ] RLS habilitado en todas las tablas
- [ ] Trigger `handle_new_user` activo
- [ ] Índice GIST `idx_comercios_location` creado
- [ ] Funciones helper disponibles
- [ ] Test de búsqueda geoespacial exitoso

---

**¿Listo para empezar?** Ejecuta `00_master_setup.sql` en Supabase SQL Editor 🚀
