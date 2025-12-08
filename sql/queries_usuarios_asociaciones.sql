-- ==========================================
-- QUERIES ÚTILES PARA USUARIOS Y ASOCIACIONES
-- ==========================================

-- ==========================================
-- 1. OBTENER USUARIO CON SUS ASOCIACIONES ADMINISTRADAS
-- ==========================================

-- Query para obtener un usuario con todas sus asociaciones
SELECT 
    u.id,
    u.email,
    u.display_name,
    u.avatar_url,
    u.rol,
    u.comercios,
    u.comercios_subs,
    u.token,
    u.ultimo_acceso,
    u.created_at,
    -- Agregamos las asociaciones como JSON array
    COALESCE(
        json_agg(
            json_build_object(
                'id', a.id,
                'nombre', a.nombre,
                'descripcion', a.descripcion,
                'logoUrl', a.logo_url,
                'adminUserId', a.admin_user_id,
                'comerciosIds', a.comercios_ids,
                'activa', a.activa,
                'createdAt', a.created_at,
                'updatedAt', a.updated_at
            )
        ) FILTER (WHERE a.id IS NOT NULL),
        '[]'::json
    ) as managed_associations
FROM usuarios u
LEFT JOIN associations a ON a.admin_user_id = u.id
WHERE u.id = 'USER_ID_AQUI'
GROUP BY u.id, u.email, u.display_name, u.avatar_url, u.rol, u.comercios, u.comercios_subs, u.token, u.ultimo_acceso, u.created_at;

-- ==========================================
-- 2. LISTAR TODOS LOS USUARIOS CON CONTEO DE ASOCIACIONES
-- ==========================================

SELECT 
    u.id,
    u.email,
    u.display_name,
    u.rol,
    u.created_at,
    COUNT(a.id) as total_asociaciones_administradas
FROM usuarios u
LEFT JOIN associations a ON a.admin_user_id = u.id
GROUP BY u.id, u.email, u.display_name, u.rol, u.created_at
ORDER BY total_asociaciones_administradas DESC, u.created_at DESC;

-- ==========================================
-- 3. OBTENER TODAS LAS ASOCIACIONES ACTIVAS
-- ==========================================

SELECT 
    a.*,
    u.email as admin_email,
    u.display_name as admin_name,
    array_length(a.comercios_ids, 1) as total_comercios
FROM associations a
JOIN usuarios u ON u.id = a.admin_user_id
WHERE a.activa = true
ORDER BY a.created_at DESC;

-- ==========================================
-- 4. BUSCAR ASOCIACIONES POR COMERCIO
-- ==========================================

-- Buscar todas las asociaciones que contienen un comercio específico
SELECT 
    a.id,
    a.nombre,
    a.descripcion,
    a.comercios_ids,
    u.email as admin_email
FROM associations a
JOIN usuarios u ON u.id = a.admin_user_id
WHERE 'COMERCIO_ID_AQUI' = ANY(a.comercios_ids)
AND a.activa = true;

-- ==========================================
-- 5. ACTUALIZAR ROL DE USUARIO A ADMIN DE ASOCIACIÓN
-- ==========================================

-- Cuando un usuario crea su primera asociación, actualizar su rol
UPDATE usuarios
SET rol = 'asociacion_admin'
WHERE id = 'USER_ID_AQUI'
AND rol != 'asociacion_admin';

-- ==========================================
-- 6. AGREGAR COMERCIO A UNA ASOCIACIÓN
-- ==========================================

-- Agregar un comercio al array de comercios_ids
UPDATE associations
SET 
    comercios_ids = array_append(comercios_ids, 'NUEVO_COMERCIO_ID'),
    updated_at = NOW()
WHERE id = 'ASSOCIATION_ID_AQUI'
AND NOT ('NUEVO_COMERCIO_ID' = ANY(comercios_ids)); -- Evitar duplicados

-- ==========================================
-- 7. REMOVER COMERCIO DE UNA ASOCIACIÓN
-- ==========================================

-- Remover un comercio del array
UPDATE associations
SET 
    comercios_ids = array_remove(comercios_ids, 'COMERCIO_ID_A_REMOVER'),
    updated_at = NOW()
WHERE id = 'ASSOCIATION_ID_AQUI';

-- ==========================================
-- 8. VERIFICAR SI UN USUARIO PUEDE ADMINISTRAR UN COMERCIO
-- ==========================================

-- Verificar si un usuario puede administrar un comercio (directamente o vía asociación)
SELECT 
    CASE 
        WHEN u.comercios @> ARRAY['COMERCIO_ID_AQUI']::TEXT[] THEN true
        WHEN EXISTS (
            SELECT 1 
            FROM associations a 
            WHERE a.admin_user_id = u.id 
            AND 'COMERCIO_ID_AQUI' = ANY(a.comercios_ids)
            AND a.activa = true
        ) THEN true
        ELSE false
    END as puede_administrar
FROM usuarios u
WHERE u.id = 'USER_ID_AQUI';

-- ==========================================
-- 9. OBTENER TODOS LOS COMERCIOS QUE PUEDE ADMINISTRAR UN USUARIO
-- ==========================================

WITH user_comercios AS (
    -- Comercios directos del usuario
    SELECT unnest(comercios) as comercio_id
    FROM usuarios
    WHERE id = 'USER_ID_AQUI'
),
association_comercios AS (
    -- Comercios de las asociaciones que administra
    SELECT unnest(comercios_ids) as comercio_id
    FROM associations
    WHERE admin_user_id = 'USER_ID_AQUI'
    AND activa = true
)
SELECT DISTINCT comercio_id
FROM (
    SELECT comercio_id FROM user_comercios
    UNION
    SELECT comercio_id FROM association_comercios
) all_comercios
ORDER BY comercio_id;

-- ==========================================
-- 10. ESTADÍSTICAS DE ASOCIACIONES
-- ==========================================

SELECT 
    COUNT(*) as total_asociaciones,
    COUNT(*) FILTER (WHERE activa = true) as asociaciones_activas,
    COUNT(*) FILTER (WHERE activa = false) as asociaciones_inactivas,
    AVG(array_length(comercios_ids, 1)) as promedio_comercios_por_asociacion,
    MAX(array_length(comercios_ids, 1)) as max_comercios_en_asociacion
FROM associations;

-- ==========================================
-- 11. DESACTIVAR ASOCIACIÓN
-- ==========================================

UPDATE associations
SET 
    activa = false,
    updated_at = NOW()
WHERE id = 'ASSOCIATION_ID_AQUI'
AND admin_user_id = 'USER_ID_AQUI'; -- Solo el admin puede desactivar

-- ==========================================
-- 12. TRANSFERIR ADMINISTRACIÓN DE ASOCIACIÓN
-- ==========================================

-- Transferir la administración a otro usuario
UPDATE associations
SET 
    admin_user_id = 'NUEVO_ADMIN_USER_ID',
    updated_at = NOW()
WHERE id = 'ASSOCIATION_ID_AQUI'
AND admin_user_id = 'ADMIN_ACTUAL_USER_ID'; -- Solo el admin actual puede transferir

-- Actualizar el rol del nuevo admin
UPDATE usuarios
SET rol = 'asociacion_admin'
WHERE id = 'NUEVO_ADMIN_USER_ID'
AND rol != 'asociacion_admin';

-- ==========================================
-- 13. BUSCAR USUARIOS POR ROL
-- ==========================================

-- Obtener todos los administradores de asociaciones
SELECT 
    u.id,
    u.email,
    u.display_name,
    COUNT(a.id) as total_asociaciones
FROM usuarios u
LEFT JOIN associations a ON a.admin_user_id = u.id AND a.activa = true
WHERE u.rol = 'asociacion_admin'
GROUP BY u.id, u.email, u.display_name
ORDER BY total_asociaciones DESC;

-- ==========================================
-- 14. ACTUALIZAR ÚLTIMO ACCESO DE USUARIO
-- ==========================================

UPDATE usuarios
SET ultimo_acceso = NOW()
WHERE id = 'USER_ID_AQUI';

-- ==========================================
-- 15. FUNCIÓN PARA CREAR ASOCIACIÓN Y ACTUALIZAR ROL
-- ==========================================

CREATE OR REPLACE FUNCTION create_association_and_update_role(
    p_nombre TEXT,
    p_descripcion TEXT,
    p_logo_url TEXT,
    p_admin_user_id UUID,
    p_comercios_ids TEXT[]
)
RETURNS UUID AS $$
DECLARE
    v_association_id UUID;
BEGIN
    -- Crear la asociación
    INSERT INTO associations (nombre, descripcion, logo_url, admin_user_id, comercios_ids, activa)
    VALUES (p_nombre, p_descripcion, p_logo_url, p_admin_user_id, p_comercios_ids, true)
    RETURNING id INTO v_association_id;
    
    -- Actualizar el rol del usuario a asociacion_admin si no lo es ya
    UPDATE usuarios
    SET rol = 'asociacion_admin'
    WHERE id = p_admin_user_id
    AND rol != 'asociacion_admin';
    
    RETURN v_association_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ejemplo de uso:
-- SELECT create_association_and_update_role(
--     'Mi Asociación',
--     'Descripción de mi asociación',
--     'https://example.com/logo.png',
--     'USER_ID_AQUI',
--     ARRAY['comercio1', 'comercio2']
-- );
