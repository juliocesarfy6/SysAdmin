#!/bin/bash
# ==================================
# main.sh
# Script principal
# ==================================

# Cargar funciones
source "$(dirname "$0")/ssh_functions.sh"

clear
echo "====================================="
echo "  CONFIGURACIÓN DE SERVICIO SSH"
echo "====================================="

echo "1. Instalar y asegurar SSH"
echo "2. Verificar estado SSH"
echo "3. Salir"
echo ""

read -p "Seleccione una opción: " opcion

case $opcion in
    1)
        instalar_y_configurar_ssh
        ;;
    2)
        verificar_estado_ssh
        ;;
    3)
        echo "Saliendo..."
        exit 0
        ;;
    *)
        echo "Opción inválida"
        ;;
esac