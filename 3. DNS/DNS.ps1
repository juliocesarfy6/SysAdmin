# Solicitar el nombre del dominio y la IP de destino
$dominio = Read-Host "Ingrese el nombre del dominio (ej: reprobados.com)"

# Expresión regular para validar una dirección IPv4
$regexIP = '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'

# Bucle para solicitar la IP hasta que sea válida
do {
    $ipDestino = Read-Host "Ingrese la dirección IP de destino (ej: 192.168.1.100)"
    if ($ipDestino -match $regexIP) {
        Write-Host "Dirección IP válida: $ipDestino"
        break
    } else {
        Write-Host "Error: La dirección IP ingresada no es válida. Inténtelo de nuevo." -ForegroundColor Red
    }
} while ($true)

# Instalar el rol de Servidor DNS si no está instalado
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Crear la zona DNS primaria
Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns"

# Agregar registros A para el dominio y www
Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ipDestino
Add-DnsServerResourceRecordA -Name "www" -ZoneName $dominio -IPv4Address $ipDestino

# Reiniciar el servicio DNS
Restart-Service DNS

Write-Host "Servidor DNS configurado con éxito para $dominio apuntando a $ipDestino"