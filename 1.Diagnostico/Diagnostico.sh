#!/bin/bash
# Script de diagnóstico inicial - Redes y Sistemas
echo "=========================================="
echo "   DIAGNÓSTICO DE NODO LINUX"
echo "=========================================="
echo "Hostname:      $(hostname)"
# Extrae la IP de la red interna (enp0s8)
echo "IP Interna:    $(ip addr show enp0s8 | grep 'inet ' | awk '{print $2}')"
echo "Espacio Disco: $(df -h / | tail -1 | awk '{print $4}') disponible"
echo "=========================================="