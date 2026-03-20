#!/bin/bash

source ../Modulos_Linux/ftp_funciones.sh

require_root

instalar_vsftpd
crear_grupos
crear_estructura
configurar_vsftpd
iniciar_servicio

menu_usuarios