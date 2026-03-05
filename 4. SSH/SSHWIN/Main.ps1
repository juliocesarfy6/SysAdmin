. .\ssh_functions.ps1

Clear-Host
Write-Host "====================================="
Write-Host "  CONFIGURACIÓN DE SERVICIO SSH"
Write-Host "====================================="

Write-Host "1. Instalar y asegurar SSH"
Write-Host "2. Verificar estado SSH"
Write-Host "3. Salir"
Write-Host ""

$option = Read-Host "Seleccione una opción"

switch ($option) {
    "1" {
        Install-AndSecure-SSH
    }
    "2" {
        Test-SSHStatus
    }
    "3" {
        Write-Host "Saliendo..."
        exit
    }
    default {
        Write-Host "Opción inválida."
    }
}
