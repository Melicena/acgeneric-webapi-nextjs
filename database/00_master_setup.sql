-- ==============================================================================
-- ACGeneric - Script Maestro de Base de Datos
-- ==============================================================================
-- Ejecuta todos los scripts de creación de tablas en el orden correcto
-- IMPORTANTE: Ejecutar en Supabase SQL Editor
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- PREREQUISITOS
-- -----------------------------------------------------------------------------
-- 1. Extensión PostGIS debe estar habilitada
-- 2. Extensión pg_trgm debe estar habilitada (búsqueda de texto)
-- 3. Usuario debe tener permisos de creación

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verificar instalación
SELECT PostGIS_Version() AS postgis_version;

-- -----------------------------------------------------------------------------
-- ORDEN DE EJECUCIÓN
-- -----------------------------------------------------------------------------
-- Los scripts deben ejecutarse en este orden debido a dependencias:
--
-- 1. 01_usuarios.sql          (depende de: auth.users)
-- 2. 02_comercios.sql          (depende de: usuarios)
-- 3. 03_ofertas.sql            (depende de: comercios, usuarios)
-- 4. 04_cupones.sql            (depende de: usuarios, ofertas, comercios)
-- 5. 05_associations.sql       (depende de: usuarios)
-- 6. 06_association_members.sql (depende de: associations, comercios)
--
-- Triggers y funciones adicionales:
-- 7. database_trigger_handle_new_user.sql (trigger para usuarios)
-- 8. database_postgis_setup.sql (configuración PostGIS)

-- ==============================================================================
-- EJECUCIÓN AUTOMÁTICA (Copiar y pegar en Supabase SQL Editor)
-- ==============================================================================

\echo '=========================================='
\echo 'ACGeneric - Creación de Base de Datos'
\echo '=========================================='
\echo ''

-- -----------------------------------------------------------------------------
-- 1. TABLA: usuarios
-- -----------------------------------------------------------------------------
\echo '1/6 Creando tabla usuarios...'
\i 01_usuarios.sql
\echo '✓ Tabla usuarios creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 2. TABLA: comercios
-- -----------------------------------------------------------------------------
\echo '2/6 Creando tabla comercios...'
\i 02_comercios.sql
\echo '✓ Tabla comercios creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 3. TABLA: ofertas
-- -----------------------------------------------------------------------------
\echo '3/6 Creando tabla ofertas...'
\i 03_ofertas.sql
\echo '✓ Tabla ofertas creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 4. TABLA: cupones
-- -----------------------------------------------------------------------------
\echo '4/6 Creando tabla cupones...'
\i 04_cupones.sql
\echo '✓ Tabla cupones creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 5. TABLA: associations
-- -----------------------------------------------------------------------------
\echo '5/6 Creando tabla associations...'
\i 05_associations.sql
\echo '✓ Tabla associations creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 6. TABLA: association_members
-- -----------------------------------------------------------------------------
\echo '6/6 Creando tabla association_members...'
\i 06_association_members.sql
\echo '✓ Tabla association_members creada'
\echo ''

-- -----------------------------------------------------------------------------
-- 7. TRIGGER: handle_new_user
-- -----------------------------------------------------------------------------
\echo 'Configurando trigger de usuarios...'
\i ../database_trigger_handle_new_user.sql
\echo '✓ Trigger handle_new_user configurado'
\echo ''

-- -----------------------------------------------------------------------------
-- 8. POSTGIS: Configuración geoespacial
-- -----------------------------------------------------------------------------
\echo 'Configurando PostGIS...'
\i ../database_postgis_setup.sql
\echo '✓ PostGIS configurado'
\echo ''

-- ==============================================================================
-- VERIFICACIÓN
-- ==============================================================================

\echo '=========================================='
\echo 'Verificación de Instalación'
\echo '=========================================='
\echo ''

-- Verificar que todas las tablas existen
DO $$
DECLARE
  tables_expected TEXT[] := ARRAY['usuarios', 'comercios', 'ofertas', 'cupones', 'associations', 'association_members'];
  table_name TEXT;
  table_exists BOOLEAN;
  all_exist BOOLEAN := true;
BEGIN
  RAISE NOTICE 'Verificando tablas...';
  
  FOREACH table_name IN ARRAY tables_expected
  LOOP
    SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = table_name
    ) INTO table_exists;
    
    IF table_exists THEN
      RAISE NOTICE '  ✓ %', table_name;
    ELSE
      RAISE WARNING '  ✗ % NO ENCONTRADA', table_name;
      all_exist := false;
    END IF;
  END LOOP;
  
  IF all_exist THEN
    RAISE NOTICE '';
    RAISE NOTICE '✓ Todas las tablas creadas correctamente';
  ELSE
    RAISE WARNING '';
    RAISE WARNING '✗ Algunas tablas no se crearon';
  END IF;
END $$;

-- Verificar RLS habilitado
\echo ''
\echo 'Verificando Row Level Security...'
SELECT 
  tablename,
  CASE WHEN rowsecurity THEN '✓ Habilitado' ELSE '✗ Deshabilitado' END AS rls_status
FROM pg_tables pt
JOIN pg_class pc ON pt.tablename = pc.relname
WHERE schemaname = 'public'
  AND tablename IN ('usuarios', 'comercios', 'ofertas', 'cupones', 'associations', 'association_members')
ORDER BY tablename;

-- Verificar índices geoespaciales
\echo ''
\echo 'Verificando índices PostGIS...'
SELECT 
  indexname,
  tablename,
  CASE WHEN indexdef LIKE '%GIST%' THEN '✓ GIST' ELSE 'Estándar' END AS index_type
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE '%location%'
ORDER BY tablename, indexname;

-- Contar políticas RLS
\echo ''
\echo 'Resumen de políticas RLS...'
SELECT 
  tablename,
  COUNT(*) AS num_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Verificar triggers
\echo ''
\echo 'Verificando triggers...'
SELECT 
  tgname AS trigger_name,
  tgrelid::regclass AS table_name,
  CASE tgtype::integer & 1
    WHEN 1 THEN 'ROW'
    ELSE 'STATEMENT'
  END AS trigger_level
FROM pg_trigger
WHERE tgname NOT LIKE 'RI_%' -- Excluir triggers de foreign keys
  AND tgrelid::regclass::text LIKE 'public.%'
ORDER BY table_name, trigger_name;

\echo ''
\echo '=========================================='
\echo '✓ Instalación Completada'
\echo '=========================================='
\echo ''
\echo 'Próximos pasos:'
\echo '1. Verificar que no hay errores arriba'
\echo '2. Probar creación de usuario con Supabase Auth'
\echo '3. Insertar comercios de prueba'
\echo '4. Ejecutar tests de las funciones helper'
\echo ''

-- ==============================================================================
-- DATOS DE PRUEBA (Opcional - Descomentar para usar)
-- ==============================================================================

/*
-- Insertar comercios de ejemplo en Madrid
INSERT INTO public.comercios (
  nombre, 
  descripcion, 
  direccion, 
  telefono, 
  horario, 
  latitud, 
  longitud, 
  imagen_url, 
  categorias,
  is_approved,
  owner_id
) VALUES 
  (
    'Restaurante Sol',
    'Cocina mediterránea en el corazón de Madrid',
    'Puerta del Sol, 1, Madrid',
    '+34 911 234 567',
    'Lunes a Domingo: 10:00-22:00',
    40.4168,
    -3.7038,
    'https://example.com/sol.jpg',
    ARRAY['Restaurante', 'Mediterránea'],
    true,
    NULL -- Asignar owner_id de un usuario real
  ),
  (
    'Cafetería Retiro',
    'Café y repostería artesanal',
    'Parque del Retiro, s/n, Madrid',
    '+34 912 345 678',
    'Lunes a Domingo: 08:00-20:00',
    40.4153,
    -3.6844,
    'https://example.com/retiro.jpg',
    ARRAY['Cafetería', 'Repostería'],
    true,
    NULL
  ),
  (
    'Tienda Gran Vía',
    'Moda y complementos',
    'Gran Vía, 25, Madrid',
    '+34 913 456 789',
    'Lunes a Sábado: 10:00-21:00',
    40.4200,
    -3.7050,
    'https://example.com/granvia.jpg',
    ARRAY['Moda', 'Complementos'],
    true,
    NULL
  );

-- Verificar que se creó la columna location automáticamente
SELECT nombre, latitud, longitud, ST_AsText(location::geometry) AS location_wkt
FROM public.comercios;

-- Test de búsqueda geoespacial
SELECT * FROM buscar_comercios_cercanos(40.4168, -3.7038, 5000, 10);
*/
