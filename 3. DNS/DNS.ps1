$interfazInterna = "Ethernet 2"

$dominio = Read-Host "Ingrese el nombre del dominio (ej: reprobados.com)"

$regexIP = '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'

do {
    $ipDestino = Read-Host "Ingrese la dirección IP de destino (ej: 192.168.1.100)"
    if ($ipDestino -match $regexIP) {
        Write-Host "Dirección IP válida: $ipDestino"
        break
    } else {
        Write-Host "Error: La dirección IP ingresada no es válida. Inténtelo de nuevo." -ForegroundColor Red
    }
} while ($true)

if (!(Get-WindowsFeature -Name DNS).Installed) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

if (-not (Get-DnsServerZone -Name $dominio -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns"
}

Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ipDestino
Add-DnsServerResourceRecordA -Name "www" -ZoneName $dominio -IPv4Address $ipDestino

Restart-Service DNS

Write-Host "Servidor DNS configurado con éxito para $dominio apuntando a $ipDestino"