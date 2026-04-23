. C:\Users\Administrator\Documents\AD2func.ps1

while($true){
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   ADMINISTRACIÓN DE ACTIVE DIRECTORY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  1. ➤ Instalar servicios"
    Write-Host "  2. ➤ Configurar Active Directory"
    Write-Host "  3. ➤ Crear nuevo usuario"
    Write-Host "  4. ➤ Crear grupos de usuarios"
    Write-Host "  5. ➤ Asignar permisos a grupos"
    Write-Host "  6. ➤ Definir política de contraseñas"
    Write-Host "  7. ➤ Activar auditoría de seguridad"
    Write-Host "  8. ➤ Activar MFA (Google Authenticator)"
    Write-Host "  9. ➤ Salir del menú"
    Write-Host "========================================" -ForegroundColor Cyan
    $opc = Read-Host "Ingresa una opción (1 a 9)"

    switch($opc){
        "1"{ InstalarAD }
        "2"{ ConfigurarDominioAD }
        "3"{ CrearUsuario }
        "4"{ CrearGruposAD }
        "5"{ ConfigurarPermisosdeGruposAD }
        "6"{ ConfigurarPoliticaContraseñaAD }
        "7"{ HabilitarAuditoriaAD }
        "8"{ ConfigurarMFAAD }
        "9"{ Write-Host "Saliendo..." -ForegroundColor Yellow; exit }
        default { Write-Host "Selecciona una opcion valida (1..9)" -ForegroundColor Yellow }
    }
}