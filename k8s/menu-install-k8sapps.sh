#!/bin/bash

# --- Definición de Colores ---
C_RESET='\e[0m'
C_ROJO='\e[1;31m'
C_VERDE='\e[1;32m'
C_AMARILLO='\e[1;33m'
C_AZUL='\e[1;34m'
C_CIAN='\e[1;36m'
C_GRIS='\e[0;37m'

# --- Configuración del Log ---
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-menu-$(date +'%Y-%m-%d_%H-%M-%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${C_AZUL}Iniciando el script de menú...${C_RESET}"
echo -e "${C_AZUL}Todo el progreso se guardará en: ${C_AMARILLO}$LOG_FILE${C_RESET}"
echo "================================================="

# --- Funciones Auxiliares ---

run_script() {
    local script_path="$1"
    local app_name="$2"
    if [ ! -f "$script_path" ]; then
        echo -e "${C_ROJO}Error: No se encontró el script en '$script_path'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    echo -e "${C_CIAN}--- Instalando $app_name ---${C_RESET}"
    chmod +x "$script_path"
    if bash "$script_path"; then
        echo -e "${C_VERDE}--- $app_name se instaló correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR: Hubo un problema instalando $app_name. ---${C_RESET}"
    fi
    echo
    read -p "Presiona Enter para volver al menú..."
}

apply_yaml() {
    local yaml_path="$1"
    local app_name="$2"
    if [ ! -f "$yaml_path" ]; then
        echo -e "${C_ROJO}Error: No se encontró el archivo YAML en '$yaml_path'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    echo -e "${C_CIAN}--- Desplegando $app_name ---${C_RESET}"
    if kubectl apply -f "$yaml_path"; then
        echo -e "${C_VERDE}--- $app_name se desplegó correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR: Hubo un problema desplegando $app_name. ---${C_RESET}"
    fi
    echo
    read -p "Presiona Enter para volver al menú..."
}

deploy_avatares() {
    local app_name="Avatares-Deployment"
    local deploy_dir="avatares-deployment"
    echo -e "${C_CIAN}--- Desplegando $app_name ---${C_RESET}"
    if [ ! -f "$deploy_dir/01-deployment-avatares-api.yaml" ] || \
       [ ! -f "$deploy_dir/02-deployment-avatares-web.yaml" ] || \
       [ ! -f "$deploy_dir/03-gateway-api.yaml" ]; then
        echo -e "${C_ROJO}Error: Faltan archivos YAML en '$deploy_dir'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    echo -e "${C_GRIS}Aplicando 01-deployment-avatares-api.yaml...${C_RESET}"
    kubectl apply -f "$deploy_dir/01-deployment-avatares-api.yaml" || { echo -e "${C_ROJO}Error en 01. Abortando.${C_RESET}"; read -p "Presiona Enter..."; return; }
    echo -e "${C_GRIS}Aplicando 02-deployment-avatares-web.yaml...${C_RESET}"
    kubectl apply -f "$deploy_dir/02-deployment-avatares-web.yaml" || { echo -e "${C_ROJO}Error en 02. Abortando.${C_RESET}"; read -p "Presiona Enter..."; return; }
    echo -e "${C_GRIS}Aplicando 03-gateway-api.yaml...${C_RESET}"
    kubectl apply -f "$deploy_dir/03-gateway-api.yaml" || { echo -e "${C_ROJO}Error en 03. Abortando.${C_RESET}"; read -p "Presiona Enter..."; return; }
    echo -e "${C_VERDE}--- $app_name se desplegó correctamente. ---${C_RESET}"
    echo
    read -p "Presiona Enter para volver al menú..."
}

# --- Función para Cloudflare Tunnel (CORREGIDA) ---
deploy_cloudflare_tunnel() {
    local app_name="Cloudflare Tunnel"
    local deploy_dir="cloudflare-tunnel"
    local deploy_yaml="$deploy_dir/cloudflared-deployment.yaml"
    local namespace="cloudflare-tunnel"

    echo -e "${C_CIAN}--- Instalando $app_name ---${C_RESET}"

    if [ ! -f "$deploy_yaml" ]; then
        echo -e "${C_ROJO}Error: No se encontró '$deploy_yaml'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo -e "${C_AMARILLO}Requerido: Token del Túnel de Cloudflare.${C_RESET}" > /dev/tty
    echo -n "Por favor, introduce tu Token y presiona [ENTER] (oculto): " > /dev/tty
    read -s -r CF_TUNNEL_TOKEN < /dev/tty
    echo "" > /dev/tty

    if [ -z "$CF_TUNNEL_TOKEN" ]; then
        echo -e "${C_ROJO}Error: El token no puede estar vacío.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo -e "${C_GRIS}Creando namespace '$namespace' si no existe...${C_RESET}"
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${C_GRIS}Configurando secreto 'cloudflared-token'...${C_RESET}"

    kubectl create secret generic cloudflared-token \
      --namespace "$namespace" \
      --from-literal=token="$CF_TUNNEL_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -

    if [ $? -ne 0 ]; then
         echo -e "${C_ROJO}Error creando el secreto.${C_RESET}"
         read -p "Presiona Enter para volver al menú..."
         return
    fi
    echo -e "${C_VERDE}Secreto configurado correctamente.${C_RESET}"

    echo -e "${C_GRIS}Desplegando Cloudflared...${C_RESET}"
    
    if kubectl apply -f "$deploy_yaml"; then
        echo -e "${C_VERDE}--- $app_name se desplegó correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR desplegando $app_name. ---${C_RESET}"
    fi
    echo
    read -p "Presiona Enter para volver al menú..."
}

# --- Bucle principal del menú ---
while true; do
    clear
    echo -e "${C_AZUL}=============================================${C_RESET}"
    echo -e "${C_AZUL}    MENU DE INSTALACIÓN DEL CLUSTER K8S${C_RESET}"
    echo -e "${C_AZUL}=============================================${C_RESET}"
    echo
    echo -e "${C_AMARILLO}--- Aplicaciones del Cluster ---${C_RESET}"
    echo -e "  ${C_GRIS}1. Instalar Cert-Manager (Helm)${C_RESET}"
    echo -e "  ${C_GRIS}2. Instalar MetalLB y Nginx Fabric Gateway (Helm)${C_RESET}"
    echo -e "  ${C_GRIS}3. Instalar Longhorn (Helm)${C_RESET}"
    echo -e "  ${C_GRIS}4. Instalar ArgoCD (Helm)${C_RESET}"
    echo -e "  ${C_GRIS}5. Instalar Kube-Prom-Stack (Helm)${C_RESET}"
    echo -e "  ${C_GRIS}6. Instalar Cloudflare Tunnel (YAML + Token)${C_RESET}"
    echo -e "  ${C_GRIS}7. Instalar Kite (Dashboard Ligero)${C_RESET}"
    echo
    echo -e "${C_AMARILLO}--- Aplicaciones Propias (YAML) ---${C_RESET}"
    echo -e "  ${C_GRIS}10. Desplegar App-Test${C_RESET}"
    echo -e "  ${C_GRIS}11. Desplegar Avatares (API + Web + Gateway)${C_RESET}"
    echo
    echo -e "  ${C_AMARILLO}q. Salir${C_RESET}"
    echo
    
    echo -n -e "${C_AMARILLO}Selecciona una opción: ${C_RESET}" > /dev/tty
    read opcion < /dev/tty

    echo "Opción seleccionada por el usuario: $opcion"

    case $opcion in
        1)  run_script "cert-manager/instalar-cert-manager.sh" "Cert-Manager" ;;
        2)  run_script "metallb/instalar-metallb-helm.sh" "MetalLB y Nginx Gateway" ;;
        3)  run_script "longhorn/instalar-longhorn-helm.sh" "Longhorn" ;;
        4)  run_script "argocd/instalar-argocd-helm.sh" "ArgoCD" ;;
        5)  run_script "kube-prom-stack/instalar-kube-prom-stack.sh" "Kube-Prom-Stack" ;;
        6)  deploy_cloudflare_tunnel ;;
        7)  run_script "kite/install-kite.sh" "Kite Dashboard" ;; # <-- Nueva opción
        
        10) apply_yaml "app-test/app-test-443.yaml" "App-Test" ;;
        11) deploy_avatares ;;

        q|Q)
            echo -e "${C_AZUL}Saliendo... Log guardado en $LOG_FILE${C_RESET}"
            break
            ;;
        *)
            echo -e "${C_ROJO}Opción no válida. Intenta de nuevo.${C_RESET}"
            read -p "Presiona Enter para continuar..." < /dev/tty
            ;;
    esac
done