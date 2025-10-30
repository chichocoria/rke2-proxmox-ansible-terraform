#!/bin/bash

# Verifica si Helm está instalado
if ! command -v helm &> /dev/null
then
    echo "Helm no está instalado. Por favor, instala Helm primero."
    exit 1
fi

#1 - Agregar MetalLB al respositorio de Helm
helm repo add metallb https://metallb.github.io/metallb
#2 - Hacer un update del repo
helm repo update
#3 - Crear el namespace
kubectl create namespace metallb
#4 - Install metalLB en el namespace metallb
helm install metallb metallb/metallb --namespace metallb
#5 - Verificar la instalación
kubectl get pods -n metallb
#6 Aplicar la configuración de MetalLB
sleep 30
kubectl apply -f metallb-config.yaml
# Verificar la configuración
kubectl get configmap -n metallb

echo "MetalLB ha sido instalado y configurado correctamente."

#Install Nginx Gateway Fabric
#Step 1: Install Gateway API Resources
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" | kubectl apply -f -
# Verify installation
kubectl get crd | grep gateway

#Step 2: Configure NGINX Gateway Fabric
# Deploy NGINX Gateway Fabric CRDs
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/crds.yaml

# Deploy NGINX Gateway Fabric
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/nodeport/deploy.yaml

# Verify the deployment
kubectl get pods -n nginx-gateway

#Patch Nginx Fabric Server to use LoadBalancer
kubectl patch svc nginx-gateway -n nginx-gateway -p '{"spec": {"type": "LoadBalancer"}}'

#Step 3: Deploy Gateway Principal
kubectl apply -f gateway-principal.yaml



