function Verificar-ServicioFTP {
    $serviceName = "FTPSVC"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -ne $service) {
        Write-Host "El servicio FTP ya está instalado." -ForegroundColor Green
    }
    else {
        Write-Host "El servicio FTP no está instalado." -ForegroundColor Yellow
        Instalar-ConfigurarFTP
    }
}

function Instalar-ConfigurarFTP {
    Write-Host "Instalando servicios necesarios para el servidor FTP..." -ForegroundColor Yellow
    Install-WindowsFeature -Name Web-Server, Web-Ftp-Server, Web-Ftp-Service, Web-Ftp-Ext, Web-Scripting-Tools -IncludeManagementTools

    Configurar-FirewallFTP
    Crear-GruposFTP
    Crear-EstructuraFTP
    Configurar-SitioFTP
    Configurar-PermisosFTP
    Configurar-AutenticacionFTP
    Configurar-AutorizacionFTP
    Configurar-SSLFTP
    Reiniciar-ServiciosFTP

    Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
}

function Configurar-FirewallFTP {
    Write-Host "Creando regla de firewall..." -ForegroundColor Yellow

    if (-not (Get-NetFirewallRule -DisplayName "FTP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -LocalPort 21 -Protocol TCP -Action Allow
    }
    else {
        Write-Host "La regla de firewall FTP ya existe." -ForegroundColor Cyan
    }
}

function Crear-GruposFTP {
    Write-Host "Creando grupos necesarios para el servidor FTP..." -ForegroundColor Yellow

    if (-not (Get-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name "reprobados" -Description "Grupo de reprobados"
    }

    if (-not (Get-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name "recursadores" -Description "Grupo de recursadores"
    }
}

function Crear-EstructuraFTP {
    Write-Host "Creando estructura de carpetas FTP..." -ForegroundColor Yellow

    $paths = @(
        "C:\FTP",
        "C:\FTP\reprobados",
        "C:\FTP\recursadores",
        "C:\FTP\LocalUser",
        "C:\FTP\LocalUser\Public",
        "C:\FTP\LocalUser\Public\General"
    )

    foreach ($path in $paths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory | Out-Null
        }
    }
}

function Configurar-SitioFTP {
    $ftpPath = "C:\FTP"
    $sitioFTP = "FTP"

    Write-Host "Configurando sitio FTP..." -ForegroundColor Yellow

    if (-not (Test-Path "IIS:\Sites\$sitioFTP")) {
        New-Website -Name $sitioFTP -Port 80 -PhysicalPath $ftpPath | Out-Null
        Remove-WebBinding -Name $sitioFTP -Protocol "http" -Port 80 -ErrorAction SilentlyContinue
        New-WebBinding -Name $sitioFTP -Protocol "ftp" -IPAddress "*" -Port 21 | Out-Null
    }

    Set-ItemProperty -Path "IIS:\Sites\$sitioFTP" -Name "ftpServer.userIsolation.mode" -Value 3
}

function Configurar-PermisosFTP {
    Write-Host "Configurando permisos de carpetas..." -ForegroundColor Yellow

    $ftpPath = "C:\FTP"
    $reprobadosPath = "C:\FTP\reprobados"
    $recursadoresPath = "C:\FTP\recursadores"
    $localuserPath = "C:\FTP\LocalUser"
    $publicPath = "C:\FTP\LocalUser\Public"
    $generalPath = "C:\FTP\LocalUser\Public\General"

    icacls $reprobadosPath /inheritance:r | Out-Null
    icacls $reprobadosPath /grant "reprobados:(OI)(CI)F" | Out-Null
    icacls $reprobadosPath /grant "Administrators:(OI)(CI)F" | Out-Null
    icacls $reprobadosPath /grant "SYSTEM:(OI)(CI)F" | Out-Null

    icacls $recursadoresPath /inheritance:r | Out-Null
    icacls $recursadoresPath /grant "recursadores:(OI)(CI)F" | Out-Null
    icacls $recursadoresPath /grant "Administrators:(OI)(CI)F" | Out-Null
    icacls $recursadoresPath /grant "SYSTEM:(OI)(CI)F" | Out-Null

    icacls $generalPath /inheritance:r | Out-Null
    icacls $generalPath /grant "IUSR:(OI)(CI)RX" | Out-Null
    icacls $generalPath /grant "reprobados:(OI)(CI)M" | Out-Null
    icacls $generalPath /grant "recursadores:(OI)(CI)M" | Out-Null
    icacls $generalPath /grant "Administrators:(OI)(CI)F" | Out-Null
    icacls $generalPath /grant "SYSTEM:(OI)(CI)F" | Out-Null

    icacls $ftpPath /grant "IUSR:RX" | Out-Null
    icacls $localuserPath /grant "IUSR:RX" | Out-Null
    icacls $publicPath /grant "IUSR:RX" | Out-Null
}

function Configurar-AutenticacionFTP {
    $sitioFTP = "FTP"
    Write-Host "Configurando autenticación FTP..." -ForegroundColor Yellow

    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
}

function Limpiar-ReglasAutorizacionFTP {
    $sitioFTP = "FTP"
    $filter = "/system.ftpServer/security/authorization"

    Clear-WebConfiguration -Filter $filter -PSPath "IIS:\" -Location $sitioFTP -ErrorAction SilentlyContinue
}

function Configurar-AutorizacionFTP {
    $sitioFTP = "FTP"
    $filter = "/system.ftpServer/security/authorization"

    Write-Host "Configurando reglas de autorización FTP..." -ForegroundColor Yellow

    Limpiar-ReglasAutorizacionFTP

    Add-WebConfiguration `
        -Filter $filter `
        -Value @{accessType="Allow"; users="anonymous"; permissions="Read"} `
        -PSPath "IIS:\" `
        -Location $sitioFTP

    Add-WebConfiguration `
        -Filter $filter `
        -Value @{accessType="Allow"; roles="reprobados"; permissions="Read, Write"} `
        -PSPath "IIS:\" `
        -Location $sitioFTP

    Add-WebConfiguration `
        -Filter $filter `
        -Value @{accessType="Allow"; roles="recursadores"; permissions="Read, Write"} `
        -PSPath "IIS:\" `
        -Location $sitioFTP
}

function Configurar-SSLFTP {
    $sitioFTP = "FTP"

    Write-Host "Ajustando SSL del sitio FTP..." -ForegroundColor Yellow
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name 'ftpServer.security.ssl.controlChannelPolicy' -Value 0
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name 'ftpServer.security.ssl.dataChannelPolicy' -Value 0
}

function Reiniciar-ServiciosFTP {
    Write-Host "Reiniciando servicios FTP..." -ForegroundColor Yellow

    Restart-Service -Name FTPSVC -ErrorAction SilentlyContinue
    Restart-Service -Name W3SVC -ErrorAction SilentlyContinue
    Restart-WebItem "IIS:\Sites\FTP" -ErrorAction SilentlyContinue

    Get-Service -Name FTPSVC
}

function Mostrar-MenuPrincipal {
    do {
        Write-Host ""
        Write-Host "¿Qué desea hacer?"
        Write-Host "[1].-Gestor de usuarios"
        Write-Host "[2].-Reconfigurar FTP"
        Write-Host "[3].-Salir"
        $opcion = Read-Host "<1/2/3>"

        switch ($opcion) {
            "1" {
                gestor_usuarios
                Reiniciar-ServiciosFTP
            }
            "2" {
                Instalar-ConfigurarFTP
            }
            "3" {
                Write-Host "Saliendo..."
            }
            default {
                Write-Host "Opción no válida" -ForegroundColor Red
            }
        }
    } while ($opcion -ne "3")
}