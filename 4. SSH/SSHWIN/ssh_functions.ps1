# Verifica si el script se ejecuta como Administrador
function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
        exit 1
    }
}

# Instala la característica OpenSSH Server
function Install-OpenSSHServer {
    Write-Host "Instalando OpenSSH Server..."

    $capability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($capability.State -ne "Installed") {
        Add-WindowsCapability -Online -Name $capability.Name
        Write-Host "OpenSSH Server instalado correctamente."
    }
    else {
        Write-Host "OpenSSH Server ya está instalado."
    }
}

# Habilita e inicia el servicio SSH
function Enable-SSHService {
    Write-Host "Configurando servicio SSH..."

    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd

    Write-Host "Servicio SSH configurado e iniciado."
}

# Configura regla de Firewall para permitir puerto 22
function Configure-FirewallSSH {
    Write-Host "Configurando regla de Firewall para puerto 22..."

    $ruleExists = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue

    if (-not $ruleExists) {
        New-NetFirewallRule `
            -Name "OpenSSH-Server-In-TCP" `
            -DisplayName "OpenSSH Server (TCP 22)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22
        Write-Host "Regla de firewall creada."
    }
    else {
        Write-Host "La regla de firewall ya existe."
    }
}

# Verifica estado del servicio
function Test-SSHStatus {
    $service = Get-Service sshd

    if ($service.Status -eq "Running") {
        Write-Host "SSH está corriendo correctamente." -ForegroundColor Green
    }
    else {
        Write-Host "SSH NO está corriendo." -ForegroundColor Red
    }
}

# Función principal de instalación completa
function Install-AndSecure-SSH {
    Test-AdminPrivileges
    Install-OpenSSHServer
    Enable-SSHService
    Configure-FirewallSSH
    Test-SSHStatus
}
