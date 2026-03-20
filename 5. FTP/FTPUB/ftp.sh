#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ftp_funciones.sh"

require_root

instalar_vsftpd
crear_grupos
crear_estructura
configurar_vsftpd
iniciar_servicio

menu_usuarios