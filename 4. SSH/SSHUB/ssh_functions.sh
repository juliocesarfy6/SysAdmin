#!/bin/bash
# ==================================
# ssh_functions.sh
# Funciones para SSH en Linux
# ==================================

# Verificar si es root
verificar_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Instalar OpenSSH Server
instalar_ssh() {
    echo "[INFO] Instalando OpenSSH Server..."
    apt update -y
    apt install -y openssh-server
}

# Iniciar y habilitar servicio
iniciar_servicio_ssh() {
    echo "[INFO] Iniciando servicio SSH..."
    systemctl start ssh
    systemctl enable ssh
}

# Configurar firewall (UFW)
configurar_firewall() {
    echo "[INFO] Configurando firewall..."

    if command -v ufw >/dev/null 2>&1; then
        ufw allow 22/tcp
        ufw reload
        echo "[INFO] Puerto 22 permitido en UFW"
    else
        echo "[WARN] UFW no está instalado"
    fi
}

# Verificar estado del servicio
verificar_estado_ssh() {
    echo "[INFO] Estado del servicio SSH:"
    systemctl status ssh --no-pager
}

# Función principal
instalar_y_configurar_ssh() {
    verificar_root
    instalar_ssh
    iniciar_servicio_ssh
    configurar_firewall
    verificar_estado_ssh
}