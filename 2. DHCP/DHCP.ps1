# 1. Instalación Idempotente
$feature = Get-WindowsFeature DHCP
if ($feature.Installed -eq $false) {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
}

# 2. Parámetros Interactivos
$ScopeName = Read-Host "Nombre del Ámbito"
$StartRange = Read-Host "IP Inicial (192.168.100.50)"
$EndRange = Read-Host "IP Final (192.168.100.150)"

# 3. Configuración
Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask 255.255.255.0
Set-DhcpServerv4OptionValue -OptionId 3 -Value "192.168.100.1" # Gateway
Set-DhcpServerv4OptionValue -OptionId 6 -Value "192.168.100.10" # DNS (Linux Srv)

# 4. Monitoreo
Get-DhcpServerv4Lease -ScopeId 192.168.100.0