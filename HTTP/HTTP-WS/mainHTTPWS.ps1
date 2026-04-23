Import-Module "$PSScriptRoot\HTTPscriptWS.psm1" -Force

$Servidores =  @()
$opc = 0
$Servidores =@(
    [PSCustomObject]@{
        NombreLTS = "ApacheLTS"
        VersionLTS = ""
        EnlaceLTS = "https://www.apachelounge.com/download"
        PatronLTS = '\/VS17\/binaries\/httpd-\d{1,}\.\d{1,}\.\d{1,}-\d{1,}-win64-VS\d{2}\.zip'
        PatronVersion = '(\d{1,}\.\d{1,}\.\d{1,})'
        NombreDEV = "N/A"
    }

    [PSCustomObject]@{
        PatronVersion = '(\d{1}\.\d{1,}\.\d{1,})'

        NombreLTS = "NginxLTS(Stable)"
        VersionLTS = ""
        EnlaceLTS = "https://nginx.org/en/download.html"
        PatronLTS = '(nginx\/Windows-\d{1}\.\d{1,}\.\d{1,})'
        
        NombreDEV = "NginxDEV_(Mainline)"
        VersionDEV = ""
        EnlaceDEV = "https://nginx.org/en/download.html"
        PatronDEV = '(nginx\/Windows-\d{1}\.\d{1,}\.\d{1,})'
    } 

    [PSCustomObject]@{
        NombreLTS = "IIS"
        NombreDEV = "N/A"
        VersionLTS = ""
        EnlaceLTS = "https://nginx.org/en/download.html"
        PatronLTS = '(nginx\/Windows-\d{1}\.\d{1,}\.\d{1,})'
    } 
)

# Dependencias de c++

if (Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" ) {
} else {
    Write-Output "Instalando Microsoft Visual C++ Redistributable..."
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile "$env:TEMP\vc_redist.x64.exe"
    Start-Process -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -Wait
} 

Write-Host "Actualizando Datos"
ActualizarDatos -Array $Servidores 
while ($true)
{
    $opc = MenuServidores
    if($opc -eq 3 )
    {
        exit
    }
    MenuDescarga -opc $opc -Servidores $Servidores

}

