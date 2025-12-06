# Configuración de Supabase

## 1. Variables de Entorno

Crea un archivo `.env.local` en la raíz del proyecto con el siguiente contenido:

```env
# Supabase Configuration
# Obtén estos valores desde tu proyecto en https://app.supabase.com
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Opcional: Para operaciones del lado del servidor que requieren privilegios elevados
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## 2. Obtener las credenciales

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto (o crea uno nuevo)
3. Ve a `Settings` → `API`
4. Copia el `Project URL` y reemplaza `your-project-url`
5. Copia el `anon/public key` y reemplaza `your-anon-key`
6. (Opcional) Copia el `service_role key` si necesitas realizar operaciones privilegiadas del lado del servidor

## 3. Uso

### Cliente para componentes del lado del cliente
```typescript
import { createClient } from '@/lib/supabase/client'

const supabase = createClient()
```

### Cliente para Server Components
```typescript
import { createClient } from '@/lib/supabase/server'

const supabase = await createClient()
```

### Cliente para Route Handlers (API Routes)
```typescript
import { createClient } from '@/lib/supabase/route'

const supabase = await createClient()
```

### Cliente para Server Actions
```typescript
import { createClient } from '@/lib/supabase/server'

const supabase = await createClient()
```

## 4. Ejemplos de uso

### Consultar datos
```typescript
const { data, error } = await supabase
  .from('tabla')
  .select('*')
```

### Insertar datos
```typescript
const { data, error } = await supabase
  .from('tabla')
  .insert({ columna: 'valor' })
```

### Actualizar datos
```typescript
const { data, error } = await supabase
  .from('tabla')
  .update({ columna: 'nuevo_valor' })
  .eq('id', 1)
```

### Eliminar datos
```typescript
const { data, error } = await supabase
  .from('tabla')
  .delete()
  .eq('id', 1)
```

### Autenticación
```typescript
// Registro
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'password123'
})

// Login
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password123'
})

// Logout
const { error } = await supabase.auth.signOut()

// Obtener usuario actual
const { data: { user } } = await supabase.auth.getUser()
```

## 5. Recursos adicionales

- [Documentación de Supabase](https://supabase.com/docs)
- [Guía de Next.js con Supabase](https://supabase.com/docs/guides/getting-started/quickstarts/nextjs)
