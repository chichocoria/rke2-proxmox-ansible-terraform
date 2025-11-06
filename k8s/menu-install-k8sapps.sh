#!/bin/bash

# --- Función para ejecutar scripts .sh ---
# $1: El path al script (ej: "cert-manager/instalar-cert-manager.sh")
# $2: El nombre amigable (ej: "Cert-Manager")
run_script() {
    local script_path="$1"
    local app_name="$2"

    if [ ! -f "$script_path" ]; then
        echo "Error: No se encontró el script en '$script_path'."
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "--- Instalando $app_name ---"
    chmod +x "$script_path"
    
    if bash "$script_path"; then
        echo "--- $app_name se instaló correctamente. ---"
    else
        echo "--- ERROR: Hubo un problema instalando $app_name. ---"
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
        echo "Error: No se encontró el archivo YAML en '$yaml_path'."
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "--- Desplegando $app_name ---"
    
    if kubectl apply -f "$yaml_path"; then
        echo "--- $app_name se desplegó correctamente. ---"
    else
        echo "--- ERROR: Hubo un problema desplegando $app_name. ---"
    fi

    echo
    read -p "Presiona Enter para volver al menú..."
}

# --- Función para el despliegue de Avatares (múltiples archivos) ---
deploy_avatares() {
    local app_name="Avatares-Deployment"
    local deploy_dir="avatares-deployment"
    
    echo "--- Desplegando $app_name ---"
    
    # Comprobamos si los archivos existen antes de aplicar
    if [ ! -f "$deploy_dir/01-deployment-avatares-api.yaml" ] || \
       [ ! -f "$deploy_dir/02-deployment-avatares-web.yaml" ] || \
       [ ! -f "$deploy_dir/03-gateway-api.yaml" ]; then
        echo "Error: Faltan archivos YAML en el directorio '$deploy_dir'."
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "Aplicando 01-deployment-avatares-api.yaml..."
    if ! kubectl apply -f "$deploy_dir/01-deployment-avatares-api.yaml"; then
        echo "--- ERROR desplegando 01-deployment-avatares-api.yaml. Abortando. ---"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    
    echo "Aplicando 02-deployment-avatares-web.yaml..."
    if ! kubectl apply -f "$deploy_dir/02-deployment-avatares-web.yaml"; then
        echo "--- ERROR desplegando 02-deployment-avatares-web.yaml. Abortando. ---"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "Aplicando 03-gateway-api.yaml..."
    if ! kubectl apply -f "$deploy_dir/03-gateway-api.yaml"; then
        echo "--- ERROR desplegando 03-gateway-api.yaml. Abortando. ---"
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "--- $app_name se desplegó correctamente. ---"
    echo
    read -p "Presiona Enter para volver al menú..."
}


# --- Bucle principal del menú ---
while true; do
    clear
    echo "============================================="
    echo "   MENU DE INSTALACIÓN DEL CLUSTER K8S"
    echo "============================================="
    echo
    echo "--- Aplicaciones del Cluster (Helm) ---"
    echo "  1. Instalar Cert-Manager y Nginx Fabric Gateway"
    echo "  2. Instalar MetalLB"
    echo "  3. Instalar Longhorn"
    echo "  4. Instalar ArgoCD"
    echo "  5. Instalar Kube-Prom-Stack"
    echo
    echo "--- Aplicaciones Propias (YAML) ---"
    echo "  10. Desplegar App-Test"
    echo "  11. Desplegar Avatares (API + Web + Gateway)"
    echo
    echo "  q. Salir"
    echo
    
    read -p "Selecciona una opción: " opcion

    case $opcion in
        # Opciones de scripts .sh
        1)  run_script "cert-manager/instalar-cert-manager.sh" "Cert-Manager y Nginx Fabric Gateway" ;;
        2)  run_script "metallb/instalar-metallb-helm.sh" "MetalLB" ;;
        3)  run_script "longhorn/instalar-longhorn-helm.sh" "Longhorn" ;;
        4)  run_script "argocd/instalar-argocd-helm.sh" "ArgoCD" ;;
        5)  run_script "kube-prom-stack/instalar-kube-prom-stack.sh" "Kube-Prom-Stack" ;;
        
        # Opciones de YAML
        10) apply_yaml "app-test/app-test.yaml" "App-Test" ;;
        11) deploy_avatares ;;

        # Salir
        q|Q)
            echo "Saliendo..."
            break
            ;;
        *)
            echo "Opción no válida. Intenta de nuevo."
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done