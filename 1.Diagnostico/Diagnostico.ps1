Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   DIAGNÓSTICO DE NODO WINDOWS"
Write-Host "=========================================="
Write-Host "Hostname:      $env:COMPUTERNAME"

$IPInterna = (Get-NetIPAddress -InterfaceAlias "Ethernet 2" -AddressFamily IPv4).IPAddress
Write-Host "IP Interna:    $IPInterna"

$Disco = Get-PSDrive C | Select-Object @{n='Libre';e={"{0:N2} GB" -f ($_.Free / 1GB)}}
Write-Host "Espacio Disco: $($Disco.Libre) disponibles"
Write-Host "=========================================="