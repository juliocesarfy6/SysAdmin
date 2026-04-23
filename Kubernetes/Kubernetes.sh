#!/bin/bash

function verificarDependencias(){
  for cmd in docker minikube kubectl; do
    if ! command -v $cmd &>/dev/null; then
      echo "[ERROR] $cmd no está instalado."
      exit 1
    fi
  done

  if ! groups $USER | grep -q '\bdocker\b'; then
    echo "[ADVERTENCIA] Tu usuario no está en el grupo 'docker'. Añadiéndolo automáticamente..."
    sudo usermod -aG docker $USER
    exec newgrp docker
  fi
}

function instalarMinikube(){
    sudo apt update -y
    sudo snap install kubectl --classic

    if ! command -v docker &>/dev/null; then
        echo "[INFO] Instalando Docker..."
        sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
        exec newgrp docker
        echo "[INFO] Docker instalado y grupo aplicado."
    else
        echo "[INFO] Docker ya está instalado."
    fi

    wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -O minikube
    chmod 755 minikube
    sudo mv minikube /usr/local/bin/
    minikube start --driver=docker --memory=2048 --cpus=2
    minikube status
}

function crearVolumenesPersistentes(){
    sudo mkdir -p /mnt/data/
    sudo chmod 777 /mnt/data/

    cat > pvmysql.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-volume
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/mnt/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

    kubectl apply -f pvmysql.yaml
}

function crearApp(){
    mkdir -p flaskapi && cd flaskapi

    cat > flaskapi.py <<EOF
import os
from flask import Flask
from flaskext.mysql import MySQL

app = Flask(name)
mysql = MySQL()

app.config["MYSQL_DATABASE_USER"] = "root"
app.config["MYSQL_DATABASE_PASSWORD"] = os.getenv("db_root_password")
app.config["MYSQL_DATABASE_DB"] = os.getenv("db_name")
app.config["MYSQL_DATABASE_HOST"] = os.getenv("MYSQL_SERVICE_HOST")
app.config["MYSQL_DATABASE_PORT"] = int(os.getenv("MYSQL_SERVICE_PORT"))
mysql.init_app(app)

@app.route('/')
def home():
    return "¡Hola desde Flask en Kubernetes con MySQL!"

if name == "main":
    app.run(host="0.0.0.0", port=5000)
EOF

    cat > requirements.txt <<EOF
Flask==1.0.3
Flask-MySQL==1.4.0
PyMySQL==0.9.3
EOF

    cat > Dockerfile <<EOF
FROM python:3.6-slim

RUN apt-get clean && apt-get -y update && \
    apt-get -y install build-essential

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "flaskapi.py"]
EOF

    eval $(minikube docker-env)
    docker build -t flask-api .
    cd ..
}

function crearRecursos(){
    eval $(minikube docker-env)

    cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: flaskapi-secrets
type: Opaque
data:
  db_root_password: YWRtaW4=
EOF
    kubectl apply -f secret.yaml

    cat > configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  confluence.cnf: |-
    [mysqld]
    character-set-server=utf8
    collation-server=utf8_bin
    default-storage-engine=INNODB
    max_allowed_packet=256M
    transaction-isolation=READ-COMMITTED
EOF
    kubectl apply -f configmap.yaml

    crearVolumenesPersistentes

    cat > mysql-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: mysql
        image: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: flaskapi-secrets
              key: db_root_password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
        - name: mysql-config-volume
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim
      - name: mysql-config-volume
        configMap:
          name: mysql-config
EOF
    kubectl apply -f mysql-deployment.yaml

    cat > mysql-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector:
    app: db
  ports:
  - port: 3306
    protocol: TCP
    name: mysql
  type: ClusterIP
EOF
    kubectl apply -f mysql-service.yaml

    cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flaskapi-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flaskapi
  template:
    metadata:
      labels:
        app: flaskapi
    spec:
      containers:
      - name: flaskapi
        image: flask-api
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        env:
        - name: db_root_password
          valueFrom:
            secretKeyRef:
              name: flaskapi-secrets
              key: db_root_password
        - name: db_name
          value: flaskapi
        - name: MYSQL_SERVICE_HOST
          value: mysql
        - name: MYSQL_SERVICE_PORT
          value: "3306"
EOF
    kubectl apply -f deployment.yaml

    cat > service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  type: LoadBalancer
  selector:
    app: flaskapi
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000
EOF
    kubectl apply -f service.yaml

    echo "[INFO] Recursos desplegados. Ejecutando minikube service flask-service"
    minikube service flask-service
}

# Menú interactivo
while true; do
  echo "Menu de opciones"
  echo "1. Verificar dependencias"
  echo "2. Instalar Minikube"
  echo "3. Crear aplicación Flask"
  echo "4. Crear recursos Kubernetes"
  echo "5. Salir"
  echo "Selecciona una opción: "
  read opc

  case $opc in
    1) verificarDependencias;;
    2) instalarMinikube;;
    3) crearApp;;
    4) crearRecursos;;
    5) echo "Saliendo..."; break;;
    *) echo "Opción inválida";;
  esac
done