
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

// Cargar variables de entorno
dotenv.config({ path: '.env.local' });

async function main() {
    console.log('--- Iniciando prueba de obtención de comercio por ID ---');
    
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY 
    
    if (!supabaseUrl || !serviceRoleKey) {
        console.error('❌ Faltan variables de entorno');
        process.exit(1);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    console.log('Cliente Supabase creado.');

    // 1. Obtener un ID de comercio existente para probar
    const { data: listData, error: listError } = await supabase
        .from('comercios')
        .select('id, nombre')
        .limit(1);

    if (listError || !listData || listData.length === 0) {
        console.error('❌ No se pudieron obtener comercios para probar:', listError);
        return;
    }

    const testId = listData[0].id;
    const testNombre = listData[0].nombre;
    console.log(`Comercio encontrado para prueba: ${testNombre} (${testId})`);

    // 2. Simular lo que hace el endpoint: buscar por ID
    console.log(`Simulando GET /api/comercios/${testId}...`);

    const { data: comercio, error } = await supabase
        .from('comercios')
        .select('*')
        .eq('id', testId)
        .single();

    if (error) {
        console.error('❌ Error al obtener detalle:', error);
    } else {
        console.log('✅ Comercio obtenido exitosamente:');
        console.log(JSON.stringify(comercio, null, 2));
        
        // Verificar campos críticos
        const requiredFields = ['id', 'nombre', 'direccion', 'telefono', 'horario', 'latitud', 'longitud', 'imagen_url'];
        const missing = requiredFields.filter(f => comercio[f] === undefined);
        
        if (missing.length > 0) {
            console.warn('⚠️ Campos faltantes en la respuesta:', missing.join(', '));
        } else {
            console.log('✅ Todos los campos esperados están presentes.');
        }
    }
}

main();
