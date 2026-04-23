#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ftp_funciones.sh"

verificar_root
instalar_servicio
configurar_servicio
menu_principal