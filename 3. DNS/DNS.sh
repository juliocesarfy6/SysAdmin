#!/bin/bash
#Configuracion de un servidor DNS en Ubuntu utilizando BIND9

# Definición de variables
DOMINIO="reprobados.com"
IP_VIRTUAL="192.168.1.177"  # IP de la máquina virtual a la que apuntará el dominio
ARCHIVO_ZONA="/etc/bind/db.$DOMINIO"

# Verificar si el script se está ejecutando con privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse con privilegios de root o con sudo."
  exit 1
fi

# Eliminar configuración previa del dominio si existe
echo "Borrando configuración existente para $DOMINIO..."
sudo sed -i "/zone \"$DOMINIO\" {/,/};/d" /etc/bind/named.conf.local  # Elimina la entrada del dominio en named.conf.local
sudo rm -f $ARCHIVO_ZONA  # Elimina el archivo de zona si ya existe

# Actualizar paquetes e instalar BIND9 si no está instalado
echo "Instalando y actualizando BIND9..."
sudo apt update
sudo apt install bind9 bind9-utils bind9-doc -y

# Crear el archivo de zona DNS para el dominio
echo "Creando archivo de zona para $DOMINIO..."
sudo tee $ARCHIVO_ZONA > /dev/null <<EOF
;
; Archivo de zona para $DOMINIO en BIND9
;
\$TTL    604800
@       IN      SOA     ns1.$DOMINIO. admin.$DOMINIO. (
                             2023101001         ; Número de serie
                             604800             ; Tiempo de actualización (refresh)
                              86400             ; Tiempo de reintento (retry)
                            2419200             ; Tiempo de expiración (expire)
                             604800 )           ; Tiempo de vida negativo (Negative Cache TTL)
;
@       IN      NS      ns1.$DOMINIO.
ns1     IN      A       $IP_VIRTUAL
@       IN      A       $IP_VIRTUAL
www     IN      A       $IP_VIRTUAL
EOF

# Configurar la zona en el archivo de configuración de BIND
echo "Añadiendo configuración de la zona en named.conf.local..."
sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF
zone "$DOMINIO" {
    type master;
    file "$ARCHIVO_ZONA";
};
EOF

# Comprobar si la configuración de BIND9 es válida
echo "Verificando configuración de BIND9..."
sudo named-checkconf  # Verifica la configuración global de BIND9
sudo named-checkzone $DOMINIO $ARCHIVO_ZONA  # Verifica el archivo de zona

if [ $? -ne 0 ]; then
  echo "Error en la configuración de BIND9. Verifica los archivos de zona."
  exit 1
fi

# Reiniciar el servicio de BIND9 para aplicar cambios
echo "Reiniciando el servicio DNS BIND9..."
sudo systemctl restart bind9

# Habilitar BIND9 para que se inicie automáticamente con el sistema
echo "Habilitando BIND9 en el arranque..."
sudo systemctl enable bind9

# Realizar pruebas de resolución DNS
echo "Verificando el funcionamiento del servidor DNS..."
nslookup $DOMINIO 127.0.0.1
dig www.$DOMINIO @127.0.0.1

echo "El servidor DNS se ha configurado correctamente"