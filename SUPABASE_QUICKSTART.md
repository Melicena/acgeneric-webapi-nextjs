# ⚡ Inicio Rápido - Supabase

## 🎯 Configuración en 3 pasos

### Opción A: Script Automático (Recomendado)

```powershell
# Ejecutar el script de configuración
.\setup-supabase.ps1
```

### Opción B: Manual

1. **Crear archivo `.env.local`** en la raíz del proyecto:

```env
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu-clave-anon
```

2. **Obtener las credenciales** desde [Supabase Dashboard](https://app.supabase.com):
   - Settings → API
   - Copia: Project URL y anon key

3. **Crear tabla de ejemplo** en Supabase SQL Editor:

```sql
create table usuarios (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  email text not null unique,
  nombre text
);

alter table usuarios enable row level security;

create policy "Permitir todo en usuarios"
  on usuarios for all using (true) with check (true);
```

## ▶️ Ejecutar

```bash
npm run dev
```

Visita: http://localhost:3000/examples

## 📚 Documentación Completa

Lee `SUPABASE_README.md` para información detallada.

## 🔗 Archivos Clave

- **Clientes de Supabase**: `lib/supabase/`
- **Server Actions**: `lib/actions/supabase-actions.ts`
- **API Routes**: `app/api/usuarios/route.ts`
- **Ejemplos**: `app/examples/`
- **Middleware**: `middleware.ts`

## 💡 Uso Básico

### Client Component
```tsx
'use client'
import { createClient } from '@/lib/supabase/client'

const supabase = createClient()
const { data } = await supabase.from('usuarios').select()
```

### Server Component
```tsx
import { createClient } from '@/lib/supabase/server'

const supabase = await createClient()
const { data } = await supabase.from('usuarios').select()
```

### API Route
```tsx
import { createClient } from '@/lib/supabase/route'
import { NextResponse } from 'next/server'

export async function GET() {
  const supabase = await createClient()
  const { data } = await supabase.from('usuarios').select()
  return NextResponse.json({ data })
}
```

## ❓ Problemas Comunes

**Error: Invalid API key**
- Verifica las variables en `.env.local`
- Reinicia el servidor: `npm run dev`

**Error: relation does not exist**
- Crea la tabla en Supabase (SQL arriba)

**No veo datos**
- Verifica las políticas RLS en Supabase
- Revisa la consola del navegador

## 🆘 Ayuda

- [Documentación de Supabase](https://supabase.com/docs)
- [Discord de Supabase](https://discord.supabase.com)
- Ver `SUPABASE_README.md` para más detalles

---

✨ ¡Listo para usar Supabase!
