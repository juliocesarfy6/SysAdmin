#!/bin/bash

# Importar funciones desde el archivo de funciones
source ./HTTPscriptUB.sh
while true;do
clear
echo "============ SERVICIOS HTTP ============"
echo "Selecciona el servicio http a instalar:"
echo "1.- Apache"
echo "2.- Tomcat"
echo "3.- Nginx"
echo "4.- Salir"
read -p "Ingrese el número de la opción: " service_option
validate_option $service_option 1 3

case $service_option in
    1) service_name="apache2" ;;
    2) service_name="tomcat10" ;;
    3) service_name="nginx" ;;
    4)
    echo "Saliendo..."
    exit 0 ;;
    *)
    echo "Escoja una opcion valida(1 al 4)"
            ;;
esac
done

    echo "Selecciona la versión a instalar:"
    echo "1.- LTS (Versión estable)"
    echo "2.- Beta (Versión en desarrollo)"
    read -p "Ingrese el número de la opción: " version_option
    validate_option $version_option 1 2

    if [ "$version_option" -eq 1 ]; then
        version_type="estable"
    else
        version_type="beta"
    fi

    determine_versions $service_name
    selected_version=$([ "$version_type" == "estable" ] && echo "$stable_version" || echo "$beta_version")

    read -p "Ingrese el puerto para configurar el servicio: " port
    validate_port $port

    install_service $service_name $selected_version $port
    echo "$service_name ha sido instalado y configurado correctamente en el puerto $port."
