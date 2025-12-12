
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

// Cargar variables de entorno
dotenv.config({ path: '.env.local' });

function createAdminClient() {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

    if (!supabaseUrl || !serviceRoleKey) {
        throw new Error('Faltan variables de entorno para Supabase Admin')
    }

    return createClient(
        supabaseUrl,
        serviceRoleKey,
        {
            auth: {
                autoRefreshToken: false,
                persistSession: false
            }
        }
    )
}

async function main() {
    console.log('--- Iniciando prueba de cliente Admin ---');
    console.log('URL:', process.env.NEXT_PUBLIC_SUPABASE_URL);
    // console.log('KEY:', process.env.SUPABASE_SERVICE_ROLE_KEY); // No loguear key completa por seguridad

    try {
        const supabase = createAdminClient();
        console.log('Cliente creado.');

        const { data, error } = await supabase
            .from('usuarios')
            .select('*')
            .limit(5);

        if (error) {
            console.error('❌ Error al consultar usuarios:', error);
        } else {
            console.log(`✅ Consulta exitosa. Se encontraron ${data.length} usuarios.`);
            console.log('Usuarios encontrados:', JSON.stringify(data, null, 2));
        }

    } catch (err) {
        console.error('❌ Excepción:', err);
    }
}

main();
