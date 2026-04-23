# Validación de campos vacíos
function validar_textos_nulos {
    param (
        [string]$texto
    )

    if (-not [string]::IsNullOrEmpty($texto)) {
        return $true
    } else {
        return $false
    }
}

# Validación para evitar espacios en el nombre de usuario
function validar_espacios {
    param(
        [string]$usuario
    )

    if ($usuario -match "\s") {
        return $false
    } else {
        return $true
    }
}

function crear_user_ad {
    param(
        [string]$dominio
    )
    Write-Host "=== INICIO DE CREACIÓN DE USUARIOS EN AD ==="

    do {
        $user = Read-Host "Por favor, ingresa el nombre del nuevo usuario"
        Write-Host "Has ingresado: $user"
        if ((validar_textos_nulos -texto $user) -eq $false) {
            Write-Host "⚠️ El nombre del usuario no puede estar vacío." -ForegroundColor Red
            $v1 = $false
            continue
        }
        if ((validar_espacios -usuario $user) -eq $false) {
            Write-Host "⚠️ El nombre del usuario no debe contener espacios." -ForegroundColor Red
            $v2 = $false
            continue
        }
    } while ($v1 -eq $false -or $v2 -eq $false)

    $password = Read-Host "Establece la contraseña para el usuario" -AsSecureString

    do {
        Write-Host "`nEscoge a qué unidad organizativa (OU) pertenecerá el usuario:"
        Write-Host "[1] OU: cuates"
        Write-Host "[2] OU: no cuates"
        $opcou = Read-Host "Selecciona una opción (1 o 2)"
        switch ($opcou) {
            1 {
                $ou = "cuates"
                Write-Host "✔️ Has seleccionado la OU 'cuates'"
            }
            2 {
                $ou = "no cuates"
                Write-Host "✔️ Has seleccionado la OU 'no cuates'"
            }
            default {
                Write-Host "❌ Opción inválida. Intenta nuevamente." -ForegroundColor Red
            }
        }

        $sdominio = $dominio.Split('.')
        $dc = $sdominio[0]
        $ds = $sdominio[1]
        $ouPath = "OU=$ou,DC=$dc,DC=$ds"
    } while ($opcou -ne 1 -and $opcou -ne 2)

    try {
        New-ADUser -Name $user -SamAccountName $user -AccountPassword $password -Enabled $true -Path $ouPath -ChangePasswordAtLogon $true
        Write-Host "✅ Usuario '$user' creado exitosamente dentro de la OU '$ou'" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error durante la creación del usuario: $_" -ForegroundColor Red
    }
}

# Comprobar si AD DS está instalado
$rol = Get-WindowsFeature -Name AD-Domain-Services

if (-not $rol.Installed) {
    Write-Host "🔍 El rol 'Active Directory Domain Services' no está presente." -ForegroundColor Red
    try {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
        Write-Host "✅ Rol 'AD DS' instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "❌ No se pudo instalar el rol 'AD DS': $($_.Exception.Message)" -ForegroundColor Red
    } 
} else {
    Write-Host "✔️ El rol 'Active Directory Domain Services' ya está instalado." -ForegroundColor Green
}

# Comprobar si el equipo es un DC
try {
    $dominio = Get-ADDomain
    Write-Host "🟢 Este servidor forma parte del dominio: $($dominio.Name)" -ForegroundColor Green
    $domainName = $dominio.DNSRoot
} catch {
    Write-Host "🔴 Este equipo aún no pertenece a un dominio o no es un controlador de dominio." -ForegroundColor Red

    $domainName = Read-Host "Escribe el nombre de dominio a crear (ej. cuates.local)"
    $netbiosName = Read-Host "Escribe el nombre NetBIOS para el dominio (ej. CUATES)"
    try {
        Install-ADDSForest -DomainName $domainName -DomainNetbiosName $netbiosName -SafeModeAdministratorPassword (Read-Host -AsSecureString "Contraseña para el modo seguro") -InstallDNS
        Write-Host "✅ Se ha configurado el dominio '$domainName' correctamente." -ForegroundColor Green
        Write-Host "🔄 Reiniciando el servidor para aplicar cambios..." -ForegroundColor Yellow
        shutdown.exe /r
        exit
    } catch {
        Write-Host "❌ Error al crear el dominio: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verificación de las OUs
$ouCuates = Get-ADOrganizationalUnit -Filter 'Name -eq "cuates"' -ErrorAction SilentlyContinue
$ouNoCuates = Get-ADOrganizationalUnit -Filter 'Name -eq "no cuates"' -ErrorAction SilentlyContinue

if ($ouCuates) {
    Write-Host "✔️ La unidad organizativa 'cuates' ya existe." -ForegroundColor Green
} else {
    Write-Host "❗ La OU 'cuates' no fue encontrada." -ForegroundColor Red
    try {
        New-ADOrganizationalUnit -Name "cuates" -ProtectedFromAccidentalDeletion $true
        Write-Host "✅ OU 'cuates' creada correctamente." -ForegroundColor Green
    } catch {
        Write-Host "❌ Error al crear la OU 'cuates': $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($ouNoCuates) {
    Write-Host "✔️ La unidad organizativa 'no cuates' ya existe." -ForegroundColor Green
} else {
    Write-Host "❗ La OU 'no cuates' no fue encontrada." -ForegroundColor Red
    try {
        New-ADOrganizationalUnit -Name "no cuates" -ProtectedFromAccidentalDeletion $true
        Write-Host "✅ OU 'no cuates' creada correctamente." -ForegroundColor Green
    } catch {
        Write-Host "❌ Error al crear la OU 'no cuates': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Reglas del firewall
Write-Host "⚙️ Configurando reglas del firewall para Active Directory..."
New-NetFirewallRule -DisplayName "Active Directory" -Direction Inbound -Protocol TCP -LocalPort 53,88,135,389,445,636,49152-65535 -Action Allow -Profile Domain -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Active Directory (UDP)" -Direction Inbound -Protocol UDP -LocalPort 53,88,389 -Action Allow -Profile Domain -ErrorAction SilentlyContinue | Out-Null
Write-Host "✅ Reglas de firewall aplicadas correctamente." -ForegroundColor Green

# Menú principal
do {
    Write-Host "`n=========== MENÚ PRINCIPAL DE USUARIOS AD ==========="
    Write-Host "[1] Crear nuevo usuario"
    Write-Host "[2] Eliminar usuario existente"
    Write-Host "[3] Aplicar políticas a las OUs"
    Write-Host "[4] Salir del menú"
    $opcion = Read-Host "Selecciona una opción"

    switch ($opcion) {
        1 {
            crear_user_ad -dominio $domainName
        }
        2 {
            eliminar_user_ad
        }
        3 {
            Write-Host "🔧 Aplicando configuraciones/políticas a las unidades organizativas..."
            # aplicar_politicas_ou
        }
        4 {
            Write-Host "👋 Cerrando el menú. ¡Hasta pronto!"
            break
        }
        default {
            Write-Host "❌ Opción inválida. Por favor, elige una de las opciones listadas." -ForegroundColor Red
        }    
    }
} while ($opcion -ne 4)
