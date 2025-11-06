#!/bin/bash

# --- Configuración de Seguridad ---
set -e
set -o pipefail

# --- Definición de Colores ---
C_RESET='\e[0m'
C_ROJO='\e[1;31m'
C_VERDE='\e[1;32m'
C_AMARILLO='\e[1;33m'
C_AZUL='\e[1;34m'
C_CIAN='\e[1;36m'
C_GRIS='\e[0;37m'

# --- Variables de Versión ---
GATEWAY_API_VERSION="v1.5.1"
NGINX_FABRIC_VERSION="v1.6.1"

# --- Verificación de Dependencias ---
echo -e "${C_AZUL}Verificando dependencias (helm y kubectl)...${C_RESET}"
if ! command -v helm &> /dev/null; then
    echo -e "${C_ROJO}Error: Helm no está instalado. Por favor, instala Helm primero.${C_RESET}"
    exit 1
fi
if ! command -v kubectl &> /dev/null; then
    echo -e "${C_ROJO}Error: kubectl no está instalado. Por favor, instala kubectl primero.${C_RESET}"
    exit 1
fi
echo -e "${C_VERDE}Dependencias encontradas.${C_RESET}"

# --- Función para instalar MetalLB ---
install_metallb() {
    echo -e "${C_CIAN}=========================================${C_RESET}"
    echo -e "${C_CIAN}--- Iniciando instalación de MetalLB ---${C_RESET}"
    
    local config_file="metallb/metallb-config.yaml"

    echo -e "${C_GRIS}[1/4] Agregando/Actualizando repositorio de MetalLB...${C_RESET}"
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update

    echo -e "${C_GRIS}[2/4] Instalando/Actualizando chart de MetalLB en namespace 'metallb'...${C_RESET}"
    helm upgrade --install metallb metallb/metallb \
        --namespace metallb \
        --create-namespace \
        --wait

    echo -e "${C_GRIS}[3/4] Verificando estado de los pods de MetalLB...${C_RESET}"
    kubectl get pods -n metallb

    if [ ! -f "$config_file" ]; then
        echo -e "${C_AMARILLO}[4/4] ADVERTENCIA: No se encontró '$config_file'.${C_RESET}"
        echo -e "${C_AMARILLO}MetalLB está instalado, pero NO configurado. Omite este paso.${C_RESET}"
    else
        echo -e "${C_GRIS}[4/4] Aplicando configuración de MetalLB desde $config_file...${C_RESET}"
        kubectl apply -f "$config_file"
        echo -e "${C_VERDE}Configuración de MetalLB aplicada.${C_RESET}"
    fi
    
    echo -e "${C_VERDE}--- MetalLB instalado. ---${C_RESET}"
}

# --- Función para instalar NGINX Gateway Fabric ---
install_nginx_gateway() {
    echo -e "${C_CIAN}=========================================${C_RESET}"
    echo -e "${C_CIAN}--- Iniciando instalación de NGINX Gateway Fabric ---${C_RESET}"

    local gateway_file="metallb/gateway-principal.yaml"

    echo -e "${C_GRIS}[1/4] Instalando CRDs de Gateway API (ref: $GATEWAY_API_VERSION)...${C_RESET}"
    kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=$GATEWAY_API_VERSION" | kubectl apply -f -

    echo -e "${C_GRIS}Esperando a que se establezcan los CRDs de Gateway API...${C_RESET}"
    kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
    kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=60s

    echo -e "${C_GRIS}[2/4] Instalando NGINX Gateway Fabric (v$NGINX_FABRIC_VERSION)...${C_RESET}"
    kubectl apply -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/$NGINX_FABRIC_VERSION/deploy/crds.yaml"
    kubectl apply -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/$NGINX_FABRIC_VERSION/deploy/nodeport/deploy.yaml"

    echo -e "${C_GRIS}Esperando a que el deployment 'nginx-gateway' esté listo...${C_RESET}"
    kubectl wait --for=condition=Available deployment/nginx-gateway -n nginx-gateway --timeout=180s
    echo -e "${C_GRIS}Pods de NGINX Gateway listos:${C_RESET}"
    kubectl get pods -n nginx-gateway

    echo -e "${C_GRIS}[3/4] Cambiando servicio 'nginx-gateway' a tipo LoadBalancer...${C_RESET}"
    kubectl patch svc nginx-gateway -n nginx-gateway -p '{"spec": {"type": "LoadBalancer"}}'
    
    echo -e "${C_GRIS}Esperando a que el LoadBalancer obtenga una IP externa...${C_RESET}"
    local external_ip=""
    for _ in {1..30}; do
        external_ip=$(kubectl get svc nginx-gateway -n nginx-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        [ -n "$external_ip" ] && break
        sleep 1
    done

    if [ -z "$external_ip" ]; then
        echo -e "${C_AMARILLO}ADVERTENCIA: El servicio LoadBalancer no obtuvo una IP externa después de 30s.${C_RESET}"
    else
        echo -e "${C_VERDE}¡Éxito! Servicio 'nginx-gateway' expuesto en la IP: $external_ip${C_RESET}"
    fi

    if [ ! -f "$gateway_file" ]; then
        echo -e "${C_AMARILLO}[4/4] ADVERTENCIA: No se encontró '$gateway_file'.${C_RESET}"
        echo -e "${C_AMARILLO}NGINX Gateway Fabric está instalado, pero el Gateway *principal* NO fue desplegado.${C_RESET}"
    else
        echo -e "${C_GRIS}[4/4] Aplicando Gateway principal desde $gateway_file...${C_RESET}"
        kubectl apply -f "$gateway_file"
        echo -e "${C_VERDE}Gateway principal aplicado.${C_RESET}"
    fi

    echo -e "${C_VERDE}--- NGINX Gateway Fabric instalado. ---${C_RESET}"
}

# --- Lógica Principal ---
install_metallb
install_nginx_gateway

echo -e "${C_CIAN}=========================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación completada!${C_RESET}"