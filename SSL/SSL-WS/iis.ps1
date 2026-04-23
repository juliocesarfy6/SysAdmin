function instalar-iis {
	Install-WindowsFeature -Name Web-Server -IncludeManagementTools
	Import-Module WebAdministration
	# Solicitar nombre del sitio y puerto
	$nombreSitio = Read-Host "Ingresa el nombre del sitio (por ejemplo: MiSitio)"
	$puerto = Read-Host "Ingresa el puerto a utilizar"
	
	# Ruta base del sitio
	$rutaFisica = "C:\inetpub\wwwroot\$nombreSitio"
	
	# Crear carpeta física si no existe
	if (-not (Test-Path $rutaFisica)) {
		New-Item -Path $rutaFisica -ItemType Directory | Out-Null
	}

	$ruta = "C:\inetpub\wwwroot\$nombreSitio\index.html"
"<!DOCTYPE html><html><body><h1>Sitio $nombreSitio funcionando</h1></body></html>" | Out-File -Encoding utf8 $ruta
	
# Crear el sitio en IIS
	if (-not (Get-Website | Where-Object { $_.Name -eq $nombreSitio })) {
		New-Website -Name $nombreSitio -Port $puerto -IPAddress "*" -PhysicalPath $rutaFisica -Force
		echo "Sitio '$nombreSitio' creado en el puerto $puerto"
	} else {
		echo "El sitio '$nombreSitio' ya existe. Usándolo..."
	}

        # Preguntar si se desea habilitar SSL
        $opc = Read-Host "¿Quieres habilitar SSL? (si/no)"
        if ($opc.ToLower() -eq "si") {
		$cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "CN=ftp.PruebaFTP.com" } | Sort-Object NotAfter -Descending | Select-Object -First 1
		$newPort = Read-Host "Puerto para el HTTPS: "

		if ($cert) {
    			# Crear el binding HTTPS primero
    			New-WebBinding -Name $nombreSitio -IPAddress "*" -Port $newPort -Protocol "https"

    			# Aplicar el certificado al binding creado
    			$certHash = $cert.GetCertHashString()
    			$bindingPath = "IIS:\SslBindings\0.0.0.0!$newPort"
    			$cert | New-Item -Path $bindingPath -Force | Out-Null

    			echo "Certificado SSL aplicado al puerto $newPort"
		} else {
    			echo "No se encontró un certificado para CN=ftp.PruebaFTP.com"
		}
	}elseif ($opc.ToLower() -eq "no") {
		echo "Configurando el sitio sin SSL en el puerto $puerto"
	} else {
		echo "Opción no válida. Debes escribir 'si' o 'no'"
		return
	}
                # Abrir puerto en firewall
                netsh advfirewall firewall add rule name="IIS_$puerto" dir=in action=allow protocol=TCP localport=$puerto | Out-Null
                iisreset | Out-Null
                echo "IIS configurado correctamente con el sitio '$nombreSitio' en el puerto $puerto"
}