function Instalar-Nginx {
    param(
		[string]$version
	)

    $destino = "C:\descargas\nginx-$version.zip"
    $rutaNginx = "C:\nginx\nginx-$version"

    Expand-Archive -Path $destino -DestinationPath "C:\nginx"
    cd $rutaNginx

    $nginxconfig = "C:\nginx\nginx-$version\conf\nginx.conf"
    $configcontent = Get-Content $nginxconfig
    #Configuramos el archivo de configuracion para cambiar el puerto
    $configcontent = $configcontent -replace 'listen       80;', "listen       8080;"
    Set-Content -Path $nginxconfig -Value $configcontent

    $usarSSL = Read-Host "¿Deseas configurar SSL en NGINX? [S/N]"
    if ($usarSSL -eq "S") {
    $newPort = Read-Host "Puerto a usar para ssl: "
        $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
        Export-PfxCertificate -Cert $cert -FilePath C:\nginx\certificado.pfx -Password (ConvertTo-SecureString -String "8080" -Force -AsPlainText)
        Export-Certificate -Cert $cert -FilePath "C:\nginx\certificado.crt"
        openssl pkcs12 -in C:\nginx\certificado.pfx -clcerts -nokeys -out C:\nginx\clave.pem -passin pass:8080
        openssl pkcs12 -in C:\nginx\certificado.pfx -nocerts -nodes -out C:\nginx\clave.key -passin pass:8080
        
        $nginxconfig = "C:\nginx\nginx-$version\conf\nginx.conf"

        # Lee el contenido del archivo
        $config = Get-Content $nginxConfig -Raw

        # Definir la nueva configuraciÃ³n HTTPS
        $newHttpsConfig = @"
server {
    listen $newPort ssl;
    server_name localhost;

    ssl_certificate C:\\nginx\clave.pem;
    ssl_certificate_key C:\\nginx\clave.key;

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root html;
        index index.html index.htm;
    }
}
"@

      # Edita el arhivo de configuracion para descomentar la seccion de httos y aÃ±adir el puerto y la ruta de los certificados
      $config = $config -replace '(?s)# HTTPS server.*?}', "# HTTPS server`r`n$newHttpsConfig"
      $config | Set-Content -Path $nginxconfig
    }

    Start-Process -FilePath "$rutaNginx\nginx.exe" -WindowStyle Hidden
}