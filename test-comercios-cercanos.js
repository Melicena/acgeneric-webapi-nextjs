
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

// Cargar variables de entorno
dotenv.config({ path: '.env.local' });

async function main() {
    console.log('--- Iniciando prueba de endpoint de comercios cercanos (RPC) ---');
    
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY // Usamos service role para probar sin autenticación de usuario
    
    if (!supabaseUrl || !serviceRoleKey) {
        console.error('❌ Faltan variables de entorno (NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY)');
        process.exit(1);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    console.log('Cliente Supabase creado.');

    // Coordenadas de prueba (Madrid, Puerta del Sol aprox)
    const lat = 40.4168;
    const long = -3.7038;
    const page = 1;
    const pageSize = 20;

    console.log(`Probando RPC get_comercios_sorted_by_distance con: Lat=${lat}, Long=${long}, Page=${page}`);

    try {
        const { data, error } = await supabase.rpc('get_comercios_sorted_by_distance', {
            user_lat: lat,
            user_long: long,
            page_number: page,
            page_size: pageSize
        });

        if (error) {
            console.error('❌ Error al llamar a RPC:', error);
            // Si el error es que la función no existe, es porque no se ha ejecutado el SQL aún.
            if (error.code === '42883') {
                console.error('💡 PISTA: Asegúrate de haber ejecutado database/07_comercios_cercanos_paginated.sql en Supabase SQL Editor.');
            }
        } else {
            console.log(`✅ RPC llamada exitosamente. Registros recibidos: ${data.length}`);
            
            if (data.length > 0) {
                console.log('Primer registro:', JSON.stringify(data[0], null, 2));
                console.log(`Total Count reportado: ${data[0].total_count}`);
                
                // Verificar campos adicionales
                const sample = data[0];
                console.log('Verificando campos solicitados:');
                console.log(`- telefono: ${sample.telefono ? 'OK' : 'MISSING/NULL'}`);
                console.log(`- horario: ${sample.horario ? 'OK' : 'MISSING/NULL'}`);
                console.log(`- imagen_url: ${sample.imagen_url ? 'OK' : 'MISSING/NULL'}`);
                console.log(`- latitud: ${sample.latitud ? 'OK' : 'MISSING/NULL'}`);
                console.log(`- longitud: ${sample.longitud ? 'OK' : 'MISSING/NULL'}`);

                // Verificar orden
                if (data.length > 1) {
                    const firstDist = data[0].distancia_km;
                    const secondDist = data[1].distancia_km;
                    console.log(`Verificación de orden: ${firstDist} <= ${secondDist} ? ${firstDist <= secondDist ? 'OK' : 'FAIL'}`);
                }
            } else {
                console.log('⚠️ No se encontraron comercios (la tabla puede estar vacía o no hay comercios aprobados).');
            }
        }

    } catch (err) {
        console.error('❌ Excepción inesperada:', err);
    }
}

main();
