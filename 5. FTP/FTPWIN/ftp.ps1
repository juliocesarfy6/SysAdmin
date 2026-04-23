$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptDir\ftp_funciones.ps1"

$modulosPath = Join-Path $scriptDir "..\Modulos_Windows"
. (Join-Path $modulosPath "usuarios.ps1")
. (Join-Path $modulosPath "validadores.ps1")

Import-Module WebAdministration -Force

Verificar-ServicioFTP
Mostrar-MenuPrincipal