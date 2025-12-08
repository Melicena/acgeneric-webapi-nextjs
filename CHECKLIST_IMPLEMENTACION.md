# ✅ Checklist de Implementación - Sistema de Usuarios y Asociaciones

## 📋 Fase 1: Preparación (5 min)

- [ ] **1.1** Leer `RESUMEN_IMPLEMENTACION.md` para entender el alcance
- [ ] **1.2** Leer `ARQUITECTURA.md` para entender la arquitectura
- [ ] **1.3** Revisar `sql/README_USUARIOS_ASOCIACIONES.md` para detalles técnicos
- [ ] **1.4** Tener acceso al panel de Supabase
- [ ] **1.5** Tener un editor SQL abierto (Supabase SQL Editor)

## 🗄️ Fase 2: Base de Datos (10-15 min)

### 2.1 Ejecutar SQL Principal
- [ ] **2.1.1** Abrir Supabase → SQL Editor
- [ ] **2.1.2** Abrir archivo `sql/usuarios_y_asociaciones.sql`
- [ ] **2.1.3** Copiar TODO el contenido del archivo
- [ ] **2.1.4** Pegar en SQL Editor de Supabase
- [ ] **2.1.5** Ejecutar (botón "Run" o Ctrl+Enter)
- [ ] **2.1.6** Verificar que no hay errores en la consola

### 2.2 Verificar Tablas Creadas
- [ ] **2.2.1** Ejecutar query de verificación:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('usuarios', 'associations');
```
- [ ] **2.2.2** Debe retornar 2 filas: `usuarios` y `associations`

### 2.3 Verificar Columnas de usuarios
- [ ] **2.3.1** Ejecutar:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'usuarios'
ORDER BY ordinal_position;
```
- [ ] **2.3.2** Verificar que existen: `token`, `ultimo_acceso`

### 2.4 Verificar Columnas de associations
- [ ] **2.4.1** Ejecutar:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'associations'
ORDER BY ordinal_position;
```
- [ ] **2.4.2** Verificar todas las columnas esperadas

### 2.5 Verificar Políticas RLS
- [ ] **2.5.1** Ejecutar:
```sql
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('usuarios', 'associations');
```
- [ ] **2.5.2** Debe mostrar políticas para ambas tablas

### 2.6 Verificar Funciones Helper
- [ ] **2.6.1** Ejecutar:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%association%';
```
- [ ] **2.6.2** Debe mostrar las funciones creadas

### 2.7 Probar Funciones
- [ ] **2.7.1** Probar `is_association_admin`:
```sql
-- Reemplazar con un user_id real
SELECT is_association_admin('USER_ID_AQUI');
```
- [ ] **2.7.2** Debe retornar `false` (si el usuario no tiene asociaciones)

## 📝 Fase 3: Tipos TypeScript (5 min)

### 3.1 Verificar Archivos Modificados
- [ ] **3.1.1** Abrir `lib/types.ts`
- [ ] **3.1.2** Verificar que existe `UserRoles` constante
- [ ] **3.1.3** Verificar que existe `AsociacionModel` interface
- [ ] **3.1.4** Verificar que `UsuarioModel` tiene `managedAssociations`
- [ ] **3.1.5** Verificar que existe `AsociacionMapper`

### 3.2 Verificar Database Types
- [ ] **3.2.1** Abrir `lib/supabase/database.types.ts`
- [ ] **3.2.2** Buscar `associations:` en el archivo
- [ ] **3.2.3** Verificar que tiene Row, Insert, Update types

### 3.3 Compilar TypeScript
- [ ] **3.3.1** Abrir terminal en el proyecto
- [ ] **3.3.2** Ejecutar: `npm run build` o `npx tsc --noEmit`
- [ ] **3.3.3** Verificar que no hay errores de compilación

## 🚀 Fase 4: API Endpoints (10 min)

### 4.1 Crear Directorio de Asociaciones
- [ ] **4.1.1** Verificar que existe `app/api/associations/`
- [ ] **4.1.2** Si no existe, crear: `mkdir -p app/api/associations/[id]`

### 4.2 Activar Endpoint de Asociaciones (Lista)
- [ ] **4.2.1** Navegar a `app/api/associations/`
- [ ] **4.2.2** Renombrar `route.ts.example` → `route.ts`
```bash
# PowerShell
mv app/api/associations/route.ts.example app/api/associations/route.ts
```

### 4.3 Activar Endpoint de Asociación Individual
- [ ] **4.3.1** Navegar a `app/api/associations/[id]/`
- [ ] **4.3.2** Renombrar `route.ts.example` → `route.ts`
```bash
# PowerShell
mv "app/api/associations/[id]/route.ts.example" "app/api/associations/[id]/route.ts"
```

### 4.4 Actualizar Endpoint de Usuarios (Opcional)
- [ ] **4.4.1** Si existe `app/api/usuarios/[id]/route.ts`, hacer backup
- [ ] **4.4.2** Revisar `app/api/usuarios/[id]/route.ts.example`
- [ ] **4.4.3** Integrar cambios necesarios para cargar asociaciones

### 4.5 Reiniciar Servidor de Desarrollo
- [ ] **4.5.1** Detener servidor (Ctrl+C)
- [ ] **4.5.2** Iniciar servidor: `npm run dev`
- [ ] **4.5.3** Verificar que inicia sin errores

## 🧪 Fase 5: Testing de Endpoints (15 min)

### 5.1 Preparar Datos de Prueba
- [ ] **5.1.1** Crear un usuario de prueba en Supabase Auth
- [ ] **5.1.2** Copiar el `user_id` generado
- [ ] **5.1.3** Insertar registro en tabla `usuarios`:
```sql
INSERT INTO usuarios (id, email, display_name, rol)
VALUES ('USER_ID_AQUI', 'test@example.com', 'Usuario Test', 'usuario')
ON CONFLICT (id) DO NOTHING;
```

### 5.2 Probar GET /api/usuarios/[id]
- [ ] **5.2.1** Abrir Postman/Thunder Client/curl
- [ ] **5.2.2** Hacer GET a: `http://localhost:3000/api/usuarios/USER_ID_AQUI`
- [ ] **5.2.3** Verificar respuesta 200 OK
- [ ] **5.2.4** Verificar que `managedAssociations` es `null` o `[]`

### 5.3 Probar POST /api/associations (Crear Asociación)
- [ ] **5.3.1** Autenticarse con el usuario de prueba
- [ ] **5.3.2** Hacer POST a: `http://localhost:3000/api/associations`
- [ ] **5.3.3** Body:
```json
{
  "nombre": "Asociación de Prueba",
  "descripcion": "Descripción de prueba",
  "comerciosIds": ["comercio-1", "comercio-2"]
}
```
- [ ] **5.3.4** Verificar respuesta 201 Created
- [ ] **5.3.5** Guardar el `id` de la asociación creada

### 5.4 Probar GET /api/associations
- [ ] **5.4.1** Hacer GET a: `http://localhost:3000/api/associations`
- [ ] **5.4.2** Verificar que retorna la asociación creada
- [ ] **5.4.3** Probar filtro: `?adminUserId=USER_ID_AQUI`
- [ ] **5.4.4** Verificar que filtra correctamente

### 5.5 Probar GET /api/associations/[id]
- [ ] **5.5.1** Hacer GET a: `http://localhost:3000/api/associations/ASSOCIATION_ID`
- [ ] **5.5.2** Verificar respuesta 200 OK
- [ ] **5.5.3** Verificar que retorna los datos correctos

### 5.6 Probar PATCH /api/associations/[id]
- [ ] **5.6.1** Autenticado como admin de la asociación
- [ ] **5.6.2** Hacer PATCH a: `http://localhost:3000/api/associations/ASSOCIATION_ID`
- [ ] **5.6.3** Body:
```json
{
  "descripcion": "Descripción actualizada"
}
```
- [ ] **5.6.4** Verificar respuesta 200 OK
- [ ] **5.6.5** Verificar que `updated_at` cambió

### 5.7 Probar Agregar Comercio
- [ ] **5.7.1** Hacer POST a: `http://localhost:3000/api/associations/ASSOCIATION_ID/comercios`
- [ ] **5.7.2** Body:
```json
{
  "comercioId": "comercio-3"
}
```
- [ ] **5.7.3** Verificar que se agregó correctamente
- [ ] **5.7.4** Verificar que no permite duplicados

### 5.8 Verificar Usuario Actualizado
- [ ] **5.8.1** Hacer GET a: `http://localhost:3000/api/usuarios/USER_ID_AQUI`
- [ ] **5.8.2** Verificar que `rol` es `'asociacion_admin'`
- [ ] **5.8.3** Verificar que `managedAssociations` contiene la asociación

## 🔐 Fase 6: Verificar Seguridad (10 min)

### 6.1 Probar RLS - Lectura Pública
- [ ] **6.1.1** Sin autenticación, hacer GET a `/api/associations`
- [ ] **6.1.2** Debe retornar solo asociaciones activas

### 6.2 Probar RLS - Creación Restringida
- [ ] **6.2.1** Sin autenticación, intentar POST a `/api/associations`
- [ ] **6.2.2** Debe retornar 401 Unauthorized

### 6.3 Probar RLS - Actualización Restringida
- [ ] **6.3.1** Autenticado como otro usuario (no admin)
- [ ] **6.3.2** Intentar PATCH a asociación de otro usuario
- [ ] **6.3.3** Debe retornar 403 Forbidden

### 6.4 Probar RLS - Eliminación Restringida
- [ ] **6.4.1** Autenticado como otro usuario (no admin)
- [ ] **6.4.2** Intentar DELETE a asociación de otro usuario
- [ ] **6.4.3** Debe retornar 403 Forbidden

### 6.5 Probar Cascada
- [ ] **6.5.1** Crear asociación de prueba
- [ ] **6.5.2** Eliminar el usuario admin
- [ ] **6.5.3** Verificar que la asociación también se eliminó

## 📱 Fase 7: Integración Kotlin/Android (Opcional)

### 7.1 Copiar Modelos
- [ ] **7.1.1** Abrir `kotlin-models/UsuarioYAsociacionModels.kt`
- [ ] **7.1.2** Copiar al proyecto Android en `data/models/`
- [ ] **7.1.3** Ajustar package name si es necesario

### 7.2 Crear Servicios de API
- [ ] **7.2.1** Crear `AssociationsService.kt`
- [ ] **7.2.2** Implementar métodos:
  - `getAssociations()`
  - `createAssociation()`
  - `updateAssociation()`
  - `addComercio()`

### 7.3 Probar desde Android
- [ ] **7.3.1** Hacer llamada a GET /api/usuarios/[id]
- [ ] **7.3.2** Verificar deserialización correcta
- [ ] **7.3.3** Verificar que `asociacionesAdministradas` se carga

## 📚 Fase 8: Documentación (5 min)

### 8.1 Revisar Documentación
- [ ] **8.1.1** Leer `sql/README_USUARIOS_ASOCIACIONES.md`
- [ ] **8.1.2** Revisar queries en `sql/queries_usuarios_asociaciones.sql`
- [ ] **8.1.3** Guardar enlaces útiles

### 8.2 Crear Documentación de Equipo
- [ ] **8.2.1** Documentar endpoints en Postman/Swagger
- [ ] **8.2.2** Crear ejemplos de uso para el equipo
- [ ] **8.2.3** Documentar casos de uso específicos del proyecto

## 🎯 Fase 9: Deploy (Producción)

### 9.1 Preparar Producción
- [ ] **9.1.1** Ejecutar SQL en base de datos de producción
- [ ] **9.1.2** Verificar variables de entorno
- [ ] **9.1.3** Hacer build de producción: `npm run build`

### 9.2 Deploy
- [ ] **9.2.1** Deploy a Vercel/Netlify/otro
- [ ] **9.2.2** Verificar que los endpoints funcionan
- [ ] **9.2.3** Probar con datos reales

### 9.3 Monitoreo
- [ ] **9.3.1** Configurar logs
- [ ] **9.3.2** Configurar alertas de errores
- [ ] **9.3.3** Monitorear performance

## ✅ Checklist Final

- [ ] ✅ Base de datos configurada correctamente
- [ ] ✅ Tipos TypeScript sin errores
- [ ] ✅ Endpoints funcionando
- [ ] ✅ Tests pasando
- [ ] ✅ Seguridad RLS verificada
- [ ] ✅ Documentación completa
- [ ] ✅ Deploy exitoso

## 🐛 Troubleshooting

### Error: "Table 'associations' does not exist"
**Solución**: Ejecutar `sql/usuarios_y_asociaciones.sql` en Supabase

### Error: "Type 'associations' does not satisfy constraint"
**Solución**: Verificar que `lib/supabase/database.types.ts` tiene la tabla `associations`

### Error: 403 Forbidden al crear asociación
**Solución**: Verificar que el usuario está autenticado y que `admin_user_id` coincide con `auth.uid()`

### Error: "Cannot read property 'managedAssociations' of null"
**Solución**: Verificar que el mapper está pasando el parámetro `managedAssociations`

### Asociaciones no aparecen en usuario
**Solución**: Verificar que el JOIN se está haciendo correctamente en el endpoint

## 📞 Recursos de Ayuda

- **Documentación Completa**: `sql/README_USUARIOS_ASOCIACIONES.md`
- **Queries Útiles**: `sql/queries_usuarios_asociaciones.sql`
- **Arquitectura**: `ARQUITECTURA.md`
- **Resumen**: `RESUMEN_IMPLEMENTACION.md`
- **Índice de Archivos**: `INDICE_ARCHIVOS.md`

---

**Tiempo estimado total**: 60-75 minutos
**Última actualización**: 2025-12-08
