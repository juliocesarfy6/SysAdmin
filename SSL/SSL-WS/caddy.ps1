function Instalar-Caddy {

    param(
		[string]$version,
		[int]$puertohttp
	)

    $versionSinV = $version.TrimStart("v")
    $zipPath = "C:\descargas\caddy-$version.zip"
    $destino = "C:\caddy"

    Expand-Archive -Path $zipPath -DestinationPath $destino

    # Crear contenido HTML y estructura
    New-Item -Path "$destino\www" -ItemType Directory -Force
    "<h1>Caddy funciona ja</h1>" | Out-File -Encoding utf8 -FilePath "$destino\www\index.html"

    # Crear Caddyfile básico
    $caddyfile = @"
{
auto_https off
}
:$puertohttp {
root * C:/caddy/www/
file_server
}

"@

    $usarSSL = Read-Host "¿Deseas configurar SSL en Caddy? [S/N]"
    if ($usarSSL -eq "S") {
    $puertossl = Read-Host "Puerto a usar para ssl: "
        $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
        Export-PfxCertificate -Cert $cert -FilePath C:\caddy\certificado.pfx -Password (ConvertTo-SecureString -String "9090" -Force -AsPlainText)
        Export-Certificate -Cert $cert -FilePath "C:\caddy\certificado.crt"
        openssl pkcs12 -in C:\caddy\certificado.pfx -nocerts -nodes -out C:\caddy\clave.key -passin pass:9090
        openssl pkcs12 -in C:\caddy\certificado.pfx -clcerts -nodes -out C:\caddy\certificado.crt -passin pass:9090

        $caddyfile += @"
:$puertossl {
tls C:/caddy/certificado.crt C:/caddy/clave.key
root * C:/caddy/www/
file_server
}
"@
    }

    $caddyfile | Out-File -Encoding utf8 -FilePath "$destino\Caddyfile"
    & "$destino\caddy.exe" run --config "$destino\Caddyfile"
}