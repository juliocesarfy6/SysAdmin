#!/bin/bash
echo "=========================================="
echo "   DIAGNÓSTICO DE NODO LINUX"
echo "=========================================="
echo "Hostname:      $(hostname)"
echo "IP Interna:    $(ip addr show enp0s8 | grep 'inet ' | awk '{print $2}')"
echo "Espacio Disco: $(df -h / | tail -1 | awk '{print $4}') disponible"
echo "=========================================="