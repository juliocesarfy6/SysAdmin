#!/bin/bash

# 1. Verificación e Instalación (Idempotencia)
if ! dpkg -s isc-dhcp-server >/dev/null 2>&1; then
    echo "Instalando isc-dhcp-server..."
    sudo apt-get update && sudo apt-get install -y isc-dhcp-server
else
    echo "El servicio ya está instalado."
fi

# 2. Orquestación (Solicitud de parámetros)
read -p "Nombre del Scope: " SCOPE_NAME
read -p "IP Inicial: " IP_START
read -p "IP Final: " IP_END
read -p "DNS Server IP: " DNS_IP

# 3. Configuración Dinámica
cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "sistemas.local";
option domain-name-servers $DNS_IP;
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.100.0 netmask 255.255.255.0 {
  range $IP_START $IP_END;
  option routers 192.168.100.1;
}
EOF

# Validar y Reiniciar
sudo dhcpd -t && sudo systemctl restart isc-dhcp-server

# 4. Monitoreo
echo "--- Concesiones Activas ---"
cat /var/lib/dhcp/dhcpd.leases