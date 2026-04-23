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
    echo "Entrando a configuraciones..."
    configurar_vsftpd
    crear_estructura_base
    crear_grupos_base
    configurar_permisos_base
    reiniciar_servicio
}

configurar_vsftpd() {
    echo "Configurando vsftpd..."

    local conf_file="/etc/vsftpd.conf"
    local backup_file="/etc/vsftpd.conf.bak"

    if [[ -f "$conf_file" && ! -f "$backup_file" ]]; then
        cp "$conf_file" "$backup_file"
        echo "Backup realizado en $backup_file"
    fi

    cat > "$conf_file" <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=YES
anon_root=/srv/ftp

local_enable=YES
write_enable=YES

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

    echo "Archivo vsftpd.conf configurado correctamente."
}

crear_estructura_base() {
    local carpeta_raiz="/srv/ftp"
    local carpetas_base=(
        "$carpeta_raiz/general"
        "$carpeta_raiz/reprobados"
        "$carpeta_raiz/recursadores"
        "$carpeta_raiz/usuarios"
    )

    echo "Configurando carpetas base del FTP..."

    if [[ ! -d "$carpeta_raiz" ]]; then
        mkdir -p "$carpeta_raiz"
        echo "Carpeta principal '$carpeta_raiz' creada."
    else
        echo "Carpeta principal '$carpeta_raiz' ya existe."
    fi

    for carpeta in "${carpetas_base[@]}"; do
        if [[ ! -d "$carpeta" ]]; then
            mkdir -p "$carpeta"
            echo "Carpeta '$carpeta' creada."
        else
            echo "Carpeta '$carpeta' ya existe."
        fi
    done

    echo "Carpetas base configuradas exitosamente."
}

crear_grupos_base() {
    local grupos=("reprobados" "recursadores")

    echo "Creando grupos locales de Linux para FTP..."

    for group_name in "${grupos[@]}"; do
        if ! getent group "$group_name" > /dev/null; then
            groupadd "$group_name"
            if [[ $? -eq 0 ]]; then
                echo "Grupo '$group_name' creado exitosamente."
            else
                echo "Error al crear el grupo '$group_name'."
                exit 1
            fi
        else
            echo "El grupo '$group_name' ya existe."
        fi
    done

    echo "Grupos locales creados exitosamente."
}

configurar_permisos_base() {
    local carpeta_raiz="/srv/ftp"
    local carpeta_general="$carpeta_raiz/general"
    local carpeta_reprobados="$carpeta_raiz/reprobados"
    local carpeta_recursadores="$carpeta_raiz/recursadores"
    local carpeta_usuarios="$carpeta_raiz/usuarios"

    apt-get install acl -y

    chmod 755 "$carpeta_raiz"
    chmod 755 "$carpeta_general"
    chmod 755 "$carpeta_usuarios"

    chown root:reprobados "$carpeta_reprobados"
    chmod 2770 "$carpeta_reprobados"

    chown root:recursadores "$carpeta_recursadores"
    chmod 2770 "$carpeta_recursadores"

    setfacl -m g:reprobados:rwx "$carpeta_general"
    setfacl -m g:recursadores:rwx "$carpeta_general"
    setfacl -d -m g:reprobados:rwx "$carpeta_general"
    setfacl -d -m g:recursadores:rwx "$carpeta_general"

    echo "Permisos base configurados correctamente."
}

reiniciar_servicio() {
    systemctl restart vsftpd
    systemctl enable vsftpd
    systemctl status vsftpd --no-pager
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
            1)
                crear_usuario
                systemctl restart vsftpd
                ;;
            2)
                eliminar_usuario
                systemctl restart vsftpd
                ;;
            3)
                editar_grupo
                systemctl restart vsftpd
                ;;
            4)
                echo "Saliendo..."
                exit 0
                ;;
            *)
                echo "Escoja una opcion valida (1 al 4)"
                ;;
        esac
    done
}