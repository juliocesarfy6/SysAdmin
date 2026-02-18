$Dominio = Read-Host "Ingrese el nombre del dominio (ej: reprobados.com)"

$regexIP = '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'

$ipActual = Get-NetIPAddress -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 -ErrorAction SilentlyContinue

if (-not $ipActual) {

    do {
        $nuevaIP = Read-Host "Ingrese IP fija para la red interna"
    } while ($nuevaIP -notmatch $regexIP)

    New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress $nuevaIP -PrefixLength 24
}

Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses 127.0.0.1

if (!(Get-WindowsFeature -Name DNS).Installed) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

if (-not (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
}

do {
    $ipDestino = Read-Host "Ingrese IP destino del cliente"
} while ($ipDestino -notmatch $regexIP)

if (-not (Get-DnsServerResourceRecord -ZoneName $Dominio -Name "" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -Name "" -ZoneName $Dominio -IPv4Address $ipDestino
}

if (-not (Get-DnsServerResourceRecord -ZoneName $Dominio -Name "www" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -Name "www" -ZoneName $Dominio -IPv4Address $ipDestino
}

Restart-Service DNS

nslookup $Dominio
nslookup www.$Dominio
