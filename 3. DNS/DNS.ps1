param(
    [Parameter(Mandatory=$true)]
    [string]$TargetIP,                 

    [Parameter(Mandatory=$true)]
    [string]$ServerIP,                

    [Parameter(Mandatory=$true)]
    [string]$MainDomain,               

    [Parameter(Mandatory=$true)]
    [string]$ExtraDomain1,             

    [Parameter(Mandatory=$true)]
    [string]$ExtraDomain2,            

    [string]$InterfaceAlias = "Ethernet 2",

    [switch]$SetStaticIP
)

function Log($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ throw $m }

if ($SetStaticIP) {

    $ipCidr = Read-Host "IP/CIDR para el servidor (ej. 192.168.100.20/24)"
    $gw     = Read-Host "Gateway SOLO si esta interfaz lo necesita (Enter si no)"
    
    $ipParts = $ipCidr.Split("/")
    $ipAddr  = $ipParts[0]
    $prefix  = [int]$ipParts[1]

    Log "Configurando IP fija en $InterfaceAlias -> $ipAddr/$prefix"

    Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($gw)) {
        New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $ipAddr -PrefixLength $prefix
    } else {
        New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $ipAddr -PrefixLength $prefix -DefaultGateway $gw
    }
}

Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses 127.0.0.1

$dnsFeature = Get-WindowsFeature DNS
if (-not $dnsFeature.Installed) {
    Log "Instalando rol DNS..."
    Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
} else {
    Log "Rol DNS ya instalado."
}

$domains = @($MainDomain, $ExtraDomain1, $ExtraDomain2)

foreach ($domain in $domains) {

    if (-not (Get-DnsServerZone -Name $domain -ErrorAction SilentlyContinue)) {
        Log "Creando zona primaria: $domain"
        Add-DnsServerPrimaryZone -Name $domain -ZoneFile "$domain.dns" -DynamicUpdate None
    } else {
        Log "Zona $domain ya existe."
    }
}

$rootA = Get-DnsServerResourceRecord -ZoneName $MainDomain -Name "" -RRType "A" -ErrorAction SilentlyContinue

if ($rootA) {
    Log "Actualizando A (root) -> $TargetIP"
    $newRec = $rootA.Clone()
    $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
    Set-DnsServerResourceRecord -ZoneName $MainDomain -OldInputObject $rootA -NewInputObject $newRec | Out-Null
} else {
    Log "Creando A (root) -> $TargetIP"
    Add-DnsServerResourceRecordA -ZoneName $MainDomain -Name "" -IPv4Address $TargetIP
}

$wwwA = Get-DnsServerResourceRecord -ZoneName $MainDomain -Name "www" -RRType "A" -ErrorAction SilentlyContinue

if ($wwwA) {
    Log "Actualizando A (www) -> $TargetIP"
    $newRec = $wwwA.Clone()
    $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
    Set-DnsServerResourceRecord -ZoneName $MainDomain -OldInputObject $wwwA -NewInputObject $newRec | Out-Null
} else {
    Log "Creando A (www) -> $TargetIP"
    Add-DnsServerResourceRecordA -ZoneName $MainDomain -Name "www" -IPv4Address $TargetIP
}

if (-not (Get-DnsServerForwarder)) {
    Log "Agregando forwarders públicos..."
    Add-DnsServerForwarder -IPAddress 8.8.8.8,1.1.1.1 -ErrorAction SilentlyContinue
}

if ((Get-Service DNS).Status -ne "Running") {
    Start-Service DNS
}

Log "DNS configurado correctamente."
Log "Pruebas sugeridas:"
Write-Host "nslookup $MainDomain 127.0.0.1"
Write-Host "nslookup www.$MainDomain 127.0.0.1"
