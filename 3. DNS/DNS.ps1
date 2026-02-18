param(
    [string]$Dominio = "reprobados.com"
)

$regexIP = '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'

$ipActual = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Dhcp"}

if ($ipActual) {
    do {
        $nuevaIP = Read-Host "El servidor usa DHCP. Ingrese IP fija"
    } while ($nuevaIP -notmatch $regexIP)

    $gateway = Read-Host "Ingrese Gateway"
    $dnsLocal = $nuevaIP

    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $nuevaIP -PrefixLength 24 -DefaultGateway $gateway
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $dnsLocal
}

if (!(Get-WindowsFeature -Name DNS).Installed) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

if (-not (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
}

do {
    $ipDestino = Read-Host "Ingrese IP destino del cliente"
} while ($ipDestino -notmatch $regexIP)

if (-not (Get-DnsServerResourceRecord -ZoneName $Dominio -Name "@" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $Dominio -IPv4Address $ipDestino
}

if (-not (Get-DnsServerResourceRecord -ZoneName $Dominio -Name "www" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -Name "www" -ZoneName $Dominio -IPv4Address $ipDestino
}

Restart-Service DNS

nslookup $Dominio
ping www.$Dominio
