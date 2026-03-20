#!/bin/bash

FTP_ROOT="/srv/ftp"
GENERAL="$FTP_ROOT/general"
REPROBADOS="$FTP_ROOT/reprobados"
RECURSADORES="$FTP_ROOT/recursadores"
USUARIOS="$FTP_ROOT/usuarios"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Ejecuta como root"
        exit 1
    fi
}

instalar_vsftpd() {
    if dpkg -s vsftpd &>/dev/null; then
        echo "vsftpd ya instalado"
    else
        echo "Instalando vsftpd..."
        apt update -y
        apt install vsftpd -y
    fi
}

crear_grupos() {
    for g in reprobados recursadores; do
        if getent group "$g" > /dev/null; then
            echo "Grupo $g ya existe"
        else
            groupadd "$g"
            echo "Grupo $g creado"
        fi
    done
}

crear_estructura() {
    mkdir -p "$GENERAL"
    mkdir -p "$REPROBADOS"
    mkdir -p "$RECURSADORES"
    mkdir -p "$USUARIOS"

    chmod 755 "$GENERAL"

    chown root:reprobados "$REPROBADOS"
    chmod 770 "$REPROBADOS"

    chown root:recursadores "$RECURSADORES"
    chmod 770 "$RECURSADORES"

    chmod 755 "$FTP_ROOT"

    echo "Estructura creada"
}

configurar_vsftpd() {
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=YES
local_enable=YES
write_enable=YES

anon_root=$GENERAL

chroot_local_user=YES
allow_writeable_chroot=YES

local_root=$USUARIOS/\$USER

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
EOF

    echo "vsftpd configurado"
}

iniciar_servicio() {
    systemctl enable vsftpd
    systemctl restart vsftpd
    systemctl status vsftpd --no-pager
}

crear_usuario() {
    read -p "Usuario: " user
    read -s -p "Password: " pass
    echo
    read -p "Grupo (reprobados/recursadores): " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido"
        return
    fi

    HOME_DIR="$USUARIOS/$user"

    useradd -M -d "$HOME_DIR" -s /usr/sbin/nologin -g "$grupo" "$user"
    echo "$user:$pass" | chpasswd

    mkdir -p "$HOME_DIR/$user"
    mkdir -p "$HOME_DIR/general"
    mkdir -p "$HOME_DIR/$grupo"

    chown root:root "$HOME_DIR"
    chmod 755 "$HOME_DIR"

    chown "$user:$grupo" "$HOME_DIR/$user"
    chmod 700 "$HOME_DIR/$user"

    mount --bind "$GENERAL" "$HOME_DIR/general"
    mount --bind "$FTP_ROOT/$grupo" "$HOME_DIR/$grupo"

    echo "Usuario creado correctamente"
}

eliminar_usuario() {
    read -p "Usuario a eliminar: " user

    umount "$USUARIOS/$user/general" 2>/dev/null
    umount "$USUARIOS/$user/reprobados" 2>/dev/null
    umount "$USUARIOS/$user/recursadores" 2>/dev/null

    userdel "$user"
    rm -rf "$USUARIOS/$user"

    echo "Usuario eliminado"
}

cambiar_grupo() {
    read -p "Usuario: " user
    read -p "Nuevo grupo: " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido"
        return
    fi

    usermod -g "$grupo" "$user"

    HOME_DIR="$USUARIOS/$user"

    umount "$HOME_DIR/reprobados" 2>/dev/null
    umount "$HOME_DIR/recursadores" 2>/dev/null

    mkdir -p "$HOME_DIR/$grupo"
    mount --bind "$FTP_ROOT/$grupo" "$HOME_DIR/$grupo"

    echo "Grupo actualizado"
}

menu_usuarios() {
    while true; do
        echo ""
        echo "1. Crear usuario"
        echo "2. Eliminar usuario"
        echo "3. Cambiar grupo"
        echo "4. Salir"
        read -p "Opción: " op

        case $op in
            1) crear_usuario ;;
            2) eliminar_usuario ;;
            3) cambiar_grupo ;;
            4) exit ;;
            *) echo "Opción inválida" ;;
        esac
    done
}