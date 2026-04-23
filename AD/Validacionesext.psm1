
function validar_ipv4 {
    param (
        [string]$IP
    )

    $regex = "^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$"

    if ($IP -match $regex) {
        Write-Host "La IP es válida" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "La IP no es válida, favor de ingresar otra" -ForegroundColor Red
        return $false
    }
}
function detalles_red {
    param (
        [string]$IPAddress,
        [int]$CIDR = 24  # Valor predeterminado si no se especifica
    )
    # Validar IP
    if ($IPAddress -notmatch "^\d{1,3}(\.\d{1,3}){3}$") {
        Write-Host "Error: IP inválida. Introduce una IP válida." -ForegroundColor Red
        return
    }

    # Tabla de máscaras de subred según el prefijo CIDR
    $subnetMasks = @{
        8  = "255.0.0.0"; 9  = "255.128.0.0"; 10 = "255.192.0.0"; 11 = "255.224.0.0"; 12 = "255.240.0.0"
        13 = "255.248.0.0"; 14 = "255.252.0.0"; 15 = "255.254.0.0"; 16 = "255.255.0.0"; 17 = "255.255.128.0"
        18 = "255.255.192.0"; 19 = "255.255.224.0"; 20 = "255.255.240.0"; 21 = "255.255.248.0"; 22 = "255.255.252.0"
        23 = "255.255.254.0"; 24 = "255.255.255.0"; 25 = "255.255.255.128"; 26 = "255.255.255.192"; 27 = "255.255.255.224"
        28 = "255.255.255.240"; 29 = "255.255.255.248"; 30 = "255.255.255.252"; 31 = "255.255.255.254"; 32 = "255.255.255.255"
    }

    # Obtener la máscara de subred
    if (-not $subnetMasks.ContainsKey($CIDR)) {
        Write-Host "Error: Prefijo CIDR inválido. Debe estar entre 8 y 32." -ForegroundColor Red
        return
    }
    $subnetMask = $subnetMasks[$CIDR]

    # Calcular la dirección de red (último octeto en 0)
    $octets = $IPAddress -split "\."
    $networkAddress = "$($octets[0]).$($octets[1]).$($octets[2]).0"

    return@($subnetMask,$networkAddress)
}

#Validacion por textos vacios
function validar_textos_nulos{
    param (
        [string]$texto
    )

    if( -not [string]::IsNullOrEmpty($texto)){
        return $true
    }else{
        return $false
    }
}
#Validacion de que el username no tenga espacios
function validar_espacios {
    param(
        [string]$usuario
    )

    if( $usuario -match "\s"){
        return $false
    }else{
        return $true
    }
}
#validcacion de formato de contrasena
function validar_contrasena {
    param (
        [string]$contrasena,
        [string]$usuario
    )

    # Verificar la longitud de la contraseña (mínimo 8, máximo 12)
    if ($contrasena.Length -lt 8 -or $contrasena.Length -gt 12) {
        return $false
    }

    # Verificar si contiene al menos una letra mayúscula
    if ($contrasena -notmatch "(?=[A-Z])") {
        return $false
    }

    # Verificar si contiene al menos un número
    if ($contrasena -notmatch "[0-9]") {
        return $false
    }

    # Verificar si la contraseña contiene el nombre de usuario (ignorando mayúsculas/minúsculas)
    if ($usuario -and ($contrasena.ToLower() -match [regex]::Escape($usuario.ToLower()))) {
        return $false
    }

    return $true
}

#Validacion de caracteres especiales
function validar_sin_caracteres_especiales {
    param (
        [string]$texto
    )

    if ($texto -match "[^a-zA-Z0-9]") {
        return $false 
    }

    return $true
}

#Validacion de 20 caracteres
function validar_longitud_maxima {
    param (
        [string]$texto
    )

    if ($texto.Length -gt 20) {
        return $false  
    }
    return $true  
}

#Validacion de que el usuario ya existe
function validar_usuario_existente {
    param (
        [string]$usuario
    )

    if (Get-LocalUser -Name $usuario -ErrorAction SilentlyContinue) {
        return $true
    } else {
        return $false
    }
}

#Validacion de que exista el grupo
function validar_grupo_existente {
    param (
        [string]$nombreGrupo
    )

    try {
        Get-ADGroup -Filter "Name -eq '$nombreGrupo'" -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Validar el puerto que se ingresa
function validar_puerto {
    param(
        [int]$Puerto
    )

    $reservedPorts = @(
        @{Port = 21; Application = "FTP"},
        @{Port = 22; Application = "SSH"},
        @{Port = 23; Application = "Telnet"},
        @{Port = 25; Application = "SMTP"},
        @{Port = 53; Application = "DNS"},
        @{Port = 110; Application = "POP3"},
        @{Port = 143; Application = "IMAP"},
        @{Port = 3306; Application = "MySQL"},
        @{Port = 3389; Application = "Remote Desktop"},
        @{Port = 5432; Application = "PostgreSQL"},
        @{Port = 5900; Application = "VNC"},
        @{Port = 6379; Application = "Redis"},
        @{Port = 27017; Application = "MongoDB"},
        @{Port = 137; Application = "NetBIOS Name Service"},
        @{Port = 138; Application = "NetBIOS Datagram Service"},
        @{Port = 161; Application = "SNMP"}
    )

    # Validar si el puerto está en el rango permitido (1-65535)
    if ($Puerto -lt 1 -or $Puerto -gt 65535) {
        Write-Host "El puerto $Puerto está fuera del rango permitido." -ForegroundColor Red
        return $false
    }
    
    # Validar si el puerto está reservado
    $reservado = $reservedPorts | Where-Object { $_.Port -eq $Puerto }
    if ($reservado) {
        Write-Host "El puerto $Puerto está reservado para $($reservado.Application)." -ForegroundColor Yellow
        return $false
    }
    
    # Verificar si el puerto está en uso
    $enUso = Get-NetTCPConnection -LocalPort $Puerto -ErrorAction SilentlyContinue
    if ($enUso) {
        Write-Host "El puerto $Puerto está en uso." -ForegroundColor Red
        return $false
    }
    
    Write-Host "El puerto $Puerto está disponible." -ForegroundColor Green
    return $true
}
