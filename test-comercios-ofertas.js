
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

// Cargar variables de entorno
dotenv.config({ path: '.env.local' });

async function main() {
    console.log('--- Iniciando prueba de endpoint comercios con ofertas ---');
    
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY 
    
    if (!supabaseUrl || !serviceRoleKey) {
        console.error('❌ Faltan variables de entorno');
        process.exit(1);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    console.log('Cliente Supabase creado.');

    // 1. Verificar si existen ofertas activas
    const { count, error: countError } = await supabase
        .from('ofertas')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)
        .gte('fecha_fin', new Date().toISOString())
        .lte('fecha_inicio', new Date().toISOString());

    // Nota: La condición de fecha es aproximada en JS, mejor dejar que la DB filtre.
    // Solo comprobamos si hay 'alguna' oferta activa.
    
    if (countError) {
        console.error('❌ Error al contar ofertas:', countError);
    } else {
        console.log(`ℹ️ Hay ${count || 0} ofertas activas potenciales en la DB.`);
    }

    // 2. Probar la función RPC directamente (simulación)
    console.log('Prueba RPC get_comercios_con_ofertas_sorted_by_distance...');
    const { data: rpcData, error: rpcError } = await supabase.rpc('get_comercios_con_ofertas_sorted_by_distance', {
        user_lat: 40.4168, // Madrid
        user_long: -3.7038,
        page_number: 1,
        page_size: 5
    });

    if (rpcError) {
        console.error('❌ Error llamando RPC:', rpcError);
        if (rpcError.code === '42883') { // Undefined function
             console.error('⚠️ La función RPC no existe. Debes ejecutar database/08_comercios_con_ofertas_cercanos.sql en tu base de datos.');
        }
    } else {
        console.log(`✅ RPC retornó ${rpcData.length} registros.`);
        if (rpcData.length > 0) {
            console.log('Ejemplo de registro:', JSON.stringify(rpcData[0], null, 2));
        }
    }

    console.log('--- Fin de la prueba ---');
}

main();
