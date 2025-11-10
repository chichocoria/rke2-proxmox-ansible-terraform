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
# 1. Crear un directorio para los logs si no existe
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# 2. Definir un nombre de archivo único para esta ejecución del script
LOG_FILE="$LOG_DIR/install-menu-$(date +'%Y-%m-%d_%H-%M-%S').log"

# 3. Redirigir TODO (stdout y stderr) a 'tee'.
# 'tee' mostrará la salida en la terminal Y la guardará en $LOG_FILE.
# '2>&1' se asegura de que los errores (stderr) también se capturen.
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${C_AZUL}Iniciando el script de menú...${C_RESET}"
echo -e "${C_AZUL}Todo el progreso se guardará en: ${C_AMARILLO}$LOG_FILE${C_RESET}"
echo "================================================="


# --- Función para ejecutar scripts .sh ---
# $1: El path al script (ej: "cert-manager/instalar-cert-manager.sh")
# $2: El nombre amigable (ej: "Cert-Manager")
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
    
    # Ejecutamos el script. Su salida ya está siendo redirigida por 'exec'
    if bash "$script_path"; then
        echo -e "${C_VERDE}--- $app_name se instaló correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR: Hubo un problema instalando $app_name. ---${C_RESET}"
    fi

    echo
    read -p "Presiona Enter para volver al menú..."
}

# --- Función para aplicar archivos YAML ---
# $1: El path al YAML (ej: "app-test/app-test.yaml")
# $2: El nombre amigable (ej: "App-Test")
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

# --- Función para el despliegue de Avatares (múltiples archivos) ---
deploy_avatares() {
    local app_name="Avatares-Deployment"
    local deploy_dir="avatares-deployment"
    
    echo -e "${C_CIAN}--- Desplegando $app_name ---${C_RESET}"
    
    # Comprobamos si los archivos existen antes de aplicar
    if [ ! -f "$deploy_dir/01-deployment-avatares-api.yaml" ] || \
       [ ! -f "$deploy_dir/02-deployment-avatares-web.yaml" ] || \
       [ ! -f "$deploy_dir/03-gateway-api.yaml" ]; then
        echo -e "${C_ROJO}Error: Faltan archivos YAML en el directorio '$deploy_dir'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo -e "${C_GRIS}Aplicando 01-deployment-avatares-api.yaml...${C_RESET}"
    if ! kubectl apply -f "$deploy_dir/01-deployment-avatares-api.yaml"; then
        echo -e "${C_ROJO}--- ERROR desplegando 01-deployment-avatares-api.yaml. Abortando. ---${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    
    echo -e "${C_GRIS}Aplicando 02-deployment-avatares-web.yaml...${C_RESET}"
    if ! kubectl apply -f "$deploy_dir/02-deployment-avatares-web.yaml"; then
        echo -e "${C_ROJO}--- ERROR desplegando 02-deployment-avatares-web.yaml. Abortando. ---${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo -e "${C_GRIS}Aplicando 03-gateway-api.yaml...${C_RESET}"
    if ! kubectl apply -f "$deploy_dir/03-gateway-api.yaml"; then
        echo -e "${C_ROJO}--- ERROR desplegando 03-gateway-api.yaml. Abortando. ---${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo -e "${C_VERDE}--- $app_name se desplegó correctamente. ---${C_RESET}"
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
    echo -e "${C_AMARILLO}--- Aplicaciones del Cluster (Helm) ---${C_RESET}"
    echo -e "  ${C_GRIS}1. Instalar Cert-Manager${C_RESET}"
    echo -e "  ${C_GRIS}2. Instalar MetalLB y Nginx Fabric Gateway${C_RESET}"
    echo -e "  ${C_GRIS}3. Instalar Longhorn${C_RESET}"
    echo -e "  ${C_GRIS}4. Instalar ArgoCD${C_RESET}"
    echo -e "  ${C_GRIS}5. Instalar Kube-Prom-Stack${C_RESET}"
    echo
    echo -e "${C_AMARILLO}--- Aplicaciones Propias (YAML) ---${C_RESET}"
    echo -e "  ${C_GRIS}10. Desplegar App-Test${C_RESET}"
    echo -e "  ${C_GRIS}11. Desplegar Avatares (API + Web + Gateway)${C_RESET}"
    echo
    echo -e "  ${C_AMARILLO}q. Salir${C_RESET}"
    echo
    
    read -p "$(echo -e ${C_AMARILLO}Selecciona una opción: ${C_RESET})" opcion

    case $opcion in
        # Opciones de scripts .sh
        1)  run_script "cert-manager/instalar-cert-manager.sh" "Cert-Manager" ;;
        2)  run_script "metallb/instalar-metallb-helm.sh" "MetalLB y Nginx Fabric Gateway" ;;
        3)  run_script "longhorn/instalar-longhorn-helm.sh" "Longhorn" ;;
        4)  run_script "argocd/instalar-argocd-helm.sh" "ArgoCD" ;;
        5)  run_script "kube-prom-stack/instalar-kube-prom-stack.sh" "Kube-Prom-Stack" ;;
        
        # Opciones de YAML
        10) apply_yaml "app-test/app-test-443.yaml" "App-Test" ;;
        11) deploy_avatares ;;

        # Salir
        q|Q)
            echo -e "${C_AZUL}Saliendo... Log guardado en $LOG_FILE${C_RESET}"
            break
            ;;
        *)
            echo -e "${C_ROJO}Opción no válida. Intenta de nuevo.${C_RESET}"
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done