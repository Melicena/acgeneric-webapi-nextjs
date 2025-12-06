@echo off
echo ========================================
echo Configurador de Supabase para Next.js
echo ========================================
echo.

REM Verificar si .env.local ya existe
if exist .env.local (
    echo El archivo .env.local ya existe.
    set /p overwrite="¿Quieres sobrescribirlo? (s/n): "
    if /i not "%overwrite%"=="s" (
        echo Operación cancelada.
        pause
        exit /b
    )
)

echo.
echo Por favor, ingresa los datos de tu proyecto de Supabase.
echo Puedes encontrarlos en: https://app.supabase.com
echo Navegando a Settings -^> API
echo.

set /p SUPABASE_URL="NEXT_PUBLIC_SUPABASE_URL (https://tu-proyecto.supabase.co): "
set /p ANON_KEY="NEXT_PUBLIC_SUPABASE_ANON_KEY: "

echo.
set /p include_service="¿Quieres incluir la SERVICE_ROLE_KEY? (s/n): "

(
echo # Supabase Configuration
echo # Generado el %date% a las %time%
echo NEXT_PUBLIC_SUPABASE_URL=%SUPABASE_URL%
echo NEXT_PUBLIC_SUPABASE_ANON_KEY=%ANON_KEY%
) > .env.local

if /i "%include_service%"=="s" (
    set /p SERVICE_KEY="SUPABASE_SERVICE_ROLE_KEY: "
    echo. >> .env.local
    echo # Opcional: Para operaciones del lado del servidor que requieren privilegios elevados >> .env.local
    echo SUPABASE_SERVICE_ROLE_KEY=!SERVICE_KEY! >> .env.local
)

echo.
echo ========================================
echo ¡Archivo .env.local creado exitosamente!
echo ========================================
echo.
echo Próximos pasos:
echo 1. Verifica que las credenciales sean correctas
echo 2. Crea las tablas necesarias en Supabase
echo 3. Ejecuta: npm run dev
echo 4. Visita: http://localhost:3000/examples
echo.
pause
