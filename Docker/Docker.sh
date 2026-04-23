#!/bin/bash

echo "Actualizando repositorios e instalando Docker..."
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker

echo "Descargando la imagen oficial de Apache desde Docker Hub..."
docker pull httpd:latest

echo "Imagen Apache LOL..."
mkdir -p apache_custom
cat <<EOF > apache_custom/index.html
<html>
  <head><title>Bienvenido al servidor web</title></head>
  <body><h1>¡Bienvenido a Los Sinaloa701!</h1></body>
</html>
EOF

cat <<EOF > apache_custom/Dockerfile
FROM httpd:latest
COPY index.html /usr/local/apache2/htdocs/index.html
EOF

docker build -t apache_custom:1.0 apache_custom

echo "Creando red personalizada para comunicación entre contenedores..."
docker network create app_network

echo "Iniciando contenedor Apache con la imagen personalizada..."
docker run -dit --name apache_server --network app_network -p 8080:80 apache_custom:1.0

read -p "Ingrese el nombre de usuario para el primer contenedor PostgreSQL: " USUARIO1
read -p "Ingrese la contraseña para el primer contenedor PostgreSQL: " CONTRASENA1

read -p "Ingrese el nombre de usuario para el segundo contenedor PostgreSQL: " USUARIO2
read -p "Ingrese la contraseña para el segundo contenedor PostgreSQL: " CONTRASENA2

echo "Levantando contenedores PostgreSQL con usuarios y contraseñas definidos..."
docker run -dit --name pg1 --network app_network \
  -e POSTGRES_PASSWORD=$CONTRASENA1 -e POSTGRES_USER=$USUARIO1 -e POSTGRES_DB=bd1 \
  postgres:latest

docker run -dit --name pg2 --network app_network \
  -e POSTGRES_PASSWORD=$CONTRASENA2 -e POSTGRES_USER=$USUARIO2 -e POSTGRES_DB=bd2 \
  postgres:latest

echo "Esperando a que PostgreSQL finalice el proceso de arranque..."
sleep 10

echo "Instalando cliente PostgreSQL en pg1 para prueba de conexión..."
docker exec pg1 apt update && docker exec pg1 apt install -y postgresql-client

echo "Probando conexión desde pg1 hacia el contenedor pg2..."
docker exec pg1 psql -h pg2 -U $USUARIO2 -d bd2
