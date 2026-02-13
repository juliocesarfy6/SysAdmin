# 1. Instalación Idempotente
$feature = Get-WindowsFeature DHCP
if ($feature.Installed -eq $false) {
    Write-Host "Instalando el rol DHCP..." -ForegroundColor Yellow
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
} else {
    Write-Host "El rol DHCP ya está instalado." -ForegroundColor Green
}

function Test-IsIPv4 ($IP) {
    return $IP -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
}

$ScopeName = Read-Host "Nombre del Ambito"

do {
    $StartRange = Read-Host "IP Inicial (ej. 192.168.100.50)"
    if (-not (Test-IsIPv4 $StartRange)) { Write-Host "Formato de IP inválido." -ForegroundColor Red }
} until (Test-IsIPv4 $StartRange)

do {
    $EndRange = Read-Host "IP Final (ej. 192.168.100.150)"
    if (-not (Test-IsIPv4 $EndRange)) { Write-Host "Formato de IP inválido." -ForegroundColor Red }
} until (Test-IsIPv4 $EndRange)

$LeaseTime = New-TimeSpan -Days 0 -Hours 8 -Minutes 0 

try {
    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask 255.255.255.0 -State Active -LeaseDuration $LeaseTime
    Set-DhcpServerv4OptionValue -OptionId 3 -Value "192.168.100.1"
    Set-DhcpServerv4OptionValue -OptionId 6 -Value "192.168.100.10" -Force
    
    Write-Host "Configuración completada exitosamente." -ForegroundColor Green
} catch {
    Write-Host "Error al configurar el ámbito: $_" -ForegroundColor Red
}

function Get-DHCPStatus {
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "   ESTADO DEL SERVICIO DHCP"
    Write-Host "=========================================="
    
    $service = Get-Service DHCPServer
    Write-Host "Servicio: $($service.Status)"
    
    Write-Host "`nConcesiones (Leases) Activas:"
    $leases = Get-DhcpServerv4Lease -ScopeId 192.168.100.0 -ErrorAction SilentlyContinue
    if ($leases) {
        $leases | Select-Object ClientIPAddress, HostName, AddressState | Format-Table -AutoSize
    } else {
        Write-Host "No hay equipos conectados actualmente." -ForegroundColor Yellow
    }
    Write-Host "=========================================="
}

Get-DHCPStatus