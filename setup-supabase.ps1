# Script de configuración de Supabase para Next.js
# PowerShell Script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configurador de Supabase para Next.js" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verificar si .env.local ya existe
if (Test-Path ".env.local") {
    Write-Host "⚠️  El archivo .env.local ya existe." -ForegroundColor Yellow
    $overwrite = Read-Host "¿Quieres sobrescribirlo? (s/n)"
    
    if ($overwrite -ne "s" -and $overwrite -ne "S") {
        Write-Host "`n❌ Operación cancelada." -ForegroundColor Red
        Read-Host "Presiona Enter para salir"
        exit
    }
}

Write-Host "`nPor favor, ingresa los datos de tu proyecto de Supabase." -ForegroundColor White
Write-Host "Puedes encontrarlos en: " -NoNewline
Write-Host "https://app.supabase.com" -ForegroundColor Blue
Write-Host "Navegando a Settings -> API`n" -ForegroundColor Gray

# Solicitar URL del proyecto
$supabaseUrl = Read-Host "NEXT_PUBLIC_SUPABASE_URL (https://tu-proyecto.supabase.co)"

# Validar URL
while ([string]::IsNullOrWhiteSpace($supabaseUrl) -or $supabaseUrl -notmatch '^https://') {
    Write-Host "❌ URL inválida. Debe comenzar con https://" -ForegroundColor Red
    $supabaseUrl = Read-Host "NEXT_PUBLIC_SUPABASE_URL"
}

# Solicitar Anon Key
$anonKey = Read-Host "NEXT_PUBLIC_SUPABASE_ANON_KEY"

# Validar Anon Key
while ([string]::IsNullOrWhiteSpace($anonKey)) {
    Write-Host "❌ La clave anon es requerida" -ForegroundColor Red
    $anonKey = Read-Host "NEXT_PUBLIC_SUPABASE_ANON_KEY"
}

# Preguntar por Service Role Key
Write-Host ""
$includeService = Read-Host "¿Quieres incluir la SERVICE_ROLE_KEY? (s/n)"

$envContent = @"
# Supabase Configuration
# Generado el $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
NEXT_PUBLIC_SUPABASE_URL=$supabaseUrl
NEXT_PUBLIC_SUPABASE_ANON_KEY=$anonKey
"@

if ($includeService -eq "s" -or $includeService -eq "S") {
    $serviceKey = Read-Host "SUPABASE_SERVICE_ROLE_KEY"
    
    if (-not [string]::IsNullOrWhiteSpace($serviceKey)) {
        $envContent += @"

# Opcional: Para operaciones del lado del servidor que requieren privilegios elevados
SUPABASE_SERVICE_ROLE_KEY=$serviceKey
"@
    }
}

# Crear el archivo .env.local
$envContent | Out-File -FilePath ".env.local" -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ ¡Archivo .env.local creado exitosamente!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "📋 Próximos pasos:" -ForegroundColor Cyan
Write-Host "1. Verifica que las credenciales sean correctas en .env.local" -ForegroundColor White
Write-Host "2. Crea las tablas necesarias en Supabase (ver SUPABASE_README.md)" -ForegroundColor White
Write-Host "3. Ejecuta: " -NoNewline -ForegroundColor White
Write-Host "npm run dev" -ForegroundColor Yellow
Write-Host "4. Visita: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:3000/examples`n" -ForegroundColor Blue

Write-Host "📚 Documentación completa en: SUPABASE_README.md`n" -ForegroundColor Gray

Read-Host "Presiona Enter para salir"
