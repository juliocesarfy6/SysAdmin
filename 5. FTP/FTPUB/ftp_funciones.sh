#!/bin/bash

verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script debe ejecutarse como root."
        exit 1
    fi
}

instalar_servicio() {
    local servicio="vsftpd"

    if command -v "$servicio" &> /dev/null; then
        echo "El servicio FTP está instalado."
    else
        echo "El servicio FTP no está instalado."
        apt-get update -y
        apt-get upgrade -y
        apt-get install vsftpd -y
    fi
}

configurar_servicio() {
    configurar_vsftpd
    crear_estructura_base
    crear_grupos_base
    configurar_permisos_base
    reiniciar_servicio
}

configurar_vsftpd() {
    local conf_file="/etc/vsftpd.conf"
    local backup_file="/etc/vsftpd.conf.bak"

    if [[ -f "$conf_file" && ! -f "$backup_file" ]]; then
        cp "$conf_file" "$backup_file"
    fi

    cat > "$conf_file" <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=YES
anon_root=/srv/ftp

local_enable=YES
write_enable=YES
local_umask=022

chroot_local_user=YES
allow_writeable_chroot=YES

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO
EOF

    echo "vsftpd configurado correctamente."
}

crear_estructura_base() {
    mkdir -p /srv/ftp/general
    mkdir -p /srv/ftp/reprobados
    mkdir -p /srv/ftp/recursadores
    mkdir -p /srv/ftp/usuarios
}

crear_grupos_base() {
    for group_name in reprobados recursadores; do
        if ! getent group "$group_name" > /dev/null; then
            groupadd "$group_name"
        fi
    done
}

configurar_permisos_base() {
    apt-get install acl -y

    chmod 755 /srv/ftp
    chmod 755 /srv/ftp/general
    chmod 755 /srv/ftp/usuarios

    chown root:reprobados /srv/ftp/reprobados
    chmod 2770 /srv/ftp/reprobados

    chown root:recursadores /srv/ftp/recursadores
    chmod 2770 /srv/ftp/recursadores

    setfacl -m g:reprobados:rwx /srv/ftp/general
    setfacl -m g:recursadores:rwx /srv/ftp/general
    setfacl -d -m g:reprobados:rwx /srv/ftp/general
    setfacl -d -m g:recursadores:rwx /srv/ftp/general

    echo "Permisos base configurados correctamente."
}

reiniciar_servicio() {
    systemctl restart vsftpd
    systemctl enable vsftpd
    systemctl status vsftpd --no-pager
}

crear_usuario() {
    read -p "Nombre de usuario: " usuario
    read -s -p "Contraseña: " password
    echo
    read -p "Grupo (reprobados/recursadores): " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido."
        return
    fi

    local home_dir="/srv/ftp/usuarios/$usuario"

    useradd -m -d "$home_dir" -s /bin/bash -g "$grupo" "$usuario"
    echo "$usuario:$password" | chpasswd

    mkdir -p "$home_dir/general"
    mkdir -p "$home_dir/$grupo"
    mkdir -p "$home_dir/$usuario"

    mount --bind /srv/ftp/general "$home_dir/general"
    mount --bind "/srv/ftp/$grupo" "$home_dir/$grupo"

    chown root:root "$home_dir"
    chmod 755 "$home_dir"

    chown "$usuario:$grupo" "$home_dir/$usuario"
    chmod 700 "$home_dir/$usuario"

    echo "Usuario creado correctamente."
}

eliminar_usuario() {
    read -p "Usuario a eliminar: " usuario

    local home_dir="/srv/ftp/usuarios/$usuario"

    if ! id "$usuario" &>/dev/null; then
        echo "El usuario '$usuario' no existe."
        return
    fi

    umount -l "$home_dir/general" 2>/dev/null
    umount -l "$home_dir/reprobados" 2>/dev/null
    umount -l "$home_dir/recursadores" 2>/dev/null

    userdel "$usuario" 2>/dev/null
    rm -rf "$home_dir"

    echo "Usuario eliminado correctamente."
}

editar_grupo() {
    read -p "Usuario: " usuario
    read -p "Nuevo grupo (reprobados/recursadores): " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido."
        return
    fi

    usermod -g "$grupo" "$usuario"

    umount "/srv/ftp/usuarios/$usuario/reprobados" 2>/dev/null
    umount "/srv/ftp/usuarios/$usuario/recursadores" 2>/dev/null

    mkdir -p "/srv/ftp/usuarios/$usuario/$grupo"
    mount --bind "/srv/ftp/$grupo" "/srv/ftp/usuarios/$usuario/$grupo"

    chown "$usuario:$grupo" "/srv/ftp/usuarios/$usuario/$usuario"

    echo "Grupo actualizado correctamente."
}

menu_principal() {
    while true; do
        echo "--Gestor de usuarios--"
        echo "[1].-Crear Usuario"
        echo "[2].-Eliminar Usuario"
        echo "[3].-Cambiar de grupo"
        echo "[4].-Salir"
        read -p "Elija una opcion: " opc

        case "$opc" in
            1) crear_usuario ; systemctl restart vsftpd ;;
            2) eliminar_usuario ; systemctl restart vsftpd ;;
            3) editar_grupo ; systemctl restart vsftpd ;;
            4) exit 0 ;;
            *) echo "Escoja una opcion valida (1 al 4)" ;;
        esac
    done
}