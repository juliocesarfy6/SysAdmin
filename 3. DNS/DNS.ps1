param(
  [Parameter(Mandatory=$true)]
  [string]$TargetIP,

  [Parameter(Mandatory=$false)]
  [string]$ServerIP,

  [string]$Domain,

  [string]$FakeZone1,

  [string]$FakeZone2,

  [ValidateSet("A","CNAME")]
  [string]$WwwMode = "CNAME",

  [switch]$SetStaticIP,

  [string]$InterfaceAlias = ""
)

if ([string]::IsNullOrWhiteSpace($Domain)) {
  $Domain = Read-Host "Ingrese el nombre del dominio funcional (ej. flaminhot.mx)"
}

if ([string]::IsNullOrWhiteSpace($FakeZone1)) {
  $FakeZone1 = Read-Host "Ingrese el nombre de la zona no funcional 1"
}

if ([string]::IsNullOrWhiteSpace($FakeZone2)) {
  $FakeZone2 = Read-Host "Ingrese el nombre de la zona no funcional 2"
}

function Log($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ throw $m }

function Get-InternalInterface {
  $configs = Get-NetIPConfiguration | Where-Object {
    $_.NetAdapter.Status -eq "Up" -and
    $_.IPv4DefaultGateway -eq $null
  }
  if ($configs.Count -eq 0) { Fail "No se encontró interfaz de red interna activa." }
  return $configs[0].InterfaceAlias
}

function Has-StaticIP($ifName){
  $ip = Get-NetIPAddress -InterfaceAlias $ifName -AddressFamily IPv4 -ErrorAction SilentlyContinue
  return ($ip | Where-Object { $_.PrefixOrigin -eq "Manual" }) -ne $null
}

function Configure-StaticIP($ifName){
  $ipCidr = Read-Host "IP/CIDR para el servidor (ej. 192.168.100.10/24)"
  $gw     = Read-Host "Gateway (si no aplica, dejar vacío)"
  $dns    = Read-Host "DNS upstream (ej. 8.8.8.8)"

  $ipParts = $ipCidr.Split("/")
  $ipAddr  = $ipParts[0]
  $prefix  = [int]$ipParts[1]

  Get-NetIPAddress -InterfaceAlias $ifName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

  if ([string]::IsNullOrWhiteSpace($gw)) {
    New-NetIPAddress -InterfaceAlias $ifName -IPAddress $ipAddr -PrefixLength $prefix
  } else {
    New-NetIPAddress -InterfaceAlias $ifName -IPAddress $ipAddr -PrefixLength $prefix -DefaultGateway $gw
  }

  Set-DnsClientServerAddress -InterfaceAlias $ifName -ServerAddresses $dns
}

if ([string]::IsNullOrWhiteSpace($InterfaceAlias)) {
  $InterfaceAlias = Get-InternalInterface
}

if ($SetStaticIP) {
  if (Has-StaticIP $InterfaceAlias) {
    Log "IP fija detectada en $InterfaceAlias."
  } else {
    Warn "No se detectó IP fija en $InterfaceAlias."
    Configure-StaticIP $InterfaceAlias
  }
}

$serverCurrentIP = (Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 |
                    Select-Object -First 1).IPAddress

if (-not $serverCurrentIP) {
  Fail "No se pudo determinar la IP del servidor."
}

$dnsFeature = Get-WindowsFeature DNS
if (-not $dnsFeature.Installed) {
  Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
}

$zone = Get-DnsServerZone -Name $Domain -ErrorAction SilentlyContinue
if (-not $zone) {
  Add-DnsServerPrimaryZone -Name $Domain -ZoneFile "$Domain.dns" -DynamicUpdate None
}

if (-not (Get-DnsServerZone -Name $FakeZone1 -ErrorAction SilentlyContinue)) {
  Add-DnsServerPrimaryZone -Name $FakeZone1 -ZoneFile "$FakeZone1.dns"
}

if (-not (Get-DnsServerZone -Name $FakeZone2 -ErrorAction SilentlyContinue)) {
  Add-DnsServerPrimaryZone -Name $FakeZone2 -ZoneFile "$FakeZone2.dns"
}

$rootA = Get-DnsServerResourceRecord -ZoneName $Domain -Name "@" -RRType "A" -ErrorAction SilentlyContinue
if ($rootA) {
  $newRec = $rootA.Clone()
  $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
  Set-DnsServerResourceRecord -ZoneName $Domain -OldInputObject $rootA -NewInputObject $newRec | Out-Null
} else {
  Add-DnsServerResourceRecordA -ZoneName $Domain -Name "@" -IPv4Address $TargetIP
}

if ($WwwMode -eq "CNAME") {
  Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "A" -ErrorAction SilentlyContinue |
    Remove-DnsServerResourceRecord -ZoneName $Domain -Force -ErrorAction SilentlyContinue

  if (-not (Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "CNAME" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordCName -ZoneName $Domain -Name "www" -HostNameAlias "$Domain"
  }
} else {
  Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "CNAME" -ErrorAction SilentlyContinue |
    Remove-DnsServerResourceRecord -ZoneName $Domain -Force -ErrorAction SilentlyContinue

  $wwwA = Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "A" -ErrorAction SilentlyContinue
  if ($wwwA) {
    $newRec = $wwwA.Clone()
    $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
    Set-DnsServerResourceRecord -ZoneName $Domain -OldInputObject $wwwA -NewInputObject $newRec | Out-Null
  } else {
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "www" -IPv4Address $TargetIP
  }
}

$svc = Get-Service -Name DNS -ErrorAction SilentlyContinue
if ($svc.Status -ne "Running") {
  Start-Service DNS
}

Log "DNS Server listo."
Log "Zonas creadas:"
Log " - $Domain (funcional)"
Log " - $FakeZone1"
Log " - $FakeZone2"
Log "Pruebas:"
Log "nslookup $Domain $serverCurrentIP"
Log "nslookup $FakeZone1 $serverCurrentIP"
