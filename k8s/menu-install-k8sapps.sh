#!/bin/bash

# Una función para ejecutar los scripts y manejar errores
# $1: El path al script que se debe ejecutar (ej: "cert-manager/instalar-cert-manager.sh")
# $2: El nombre amigable de la aplicación (ej: "Cert-Manager")
run_script() {
    local script_path="$1"
    local app_name="$2"

    if [ ! -f "$script_path" ]; then
        echo "Error: No se encontró el script en '$script_path'."
        read -p "Presiona Enter para volver al menú..."
        return
    fi

    echo "--- Instalando $app_name ---"
    
    # Damos permisos de ejecución por si acaso
    chmod +x "$script_path"
    
    # Ejecutamos el script
    if bash "$script_path"; then
        echo "--- $app_name se instaló correctamente. ---"
    else
        echo "--- ERROR: Hubo un problema instalando $app_name. Revisa los logs. ---"
    fi

    echo
    read -p "Presiona Enter para volver al menú..."
}

# Bucle principal del menú
while true; do
    clear # Limpia la pantalla para mostrar el menú
    echo "============================================="
    echo "   MENU DE INSTALACIÓN DEL CLUSTER K8S"
    echo "============================================="
    echo
    echo "1. Instalar Cert-Manager"
    echo "2. Instalar MetalLB and Nginx Gateway Fabric"
    echo "3. Instalar Longhorn"
    echo "4. Instalar ArgoCD"
    echo "5. Instalar Kube-Prom-Stack (Prometheus)"
    echo
    echo "q. Salir"
    echo
    
    read -p "Selecciona una opción [1-5, q]: " opcion

    case $opcion in
        1)
            run_script "cert-manager/instalar-cert-manager.sh" "Cert-Manager"
            ;;
        2)
            run_script "metallb/instalar-metallb-helm.sh" "MetalLB and Nginx Gateway Fabric"
            ;;
        3)
            run_script "longhorn/instalar-longhorn-helm.sh" "Longhorn"
            ;;
        4)
            run_script "argocd/instalar-argocd-helm.sh" "ArgoCD"
            ;;
        5)
            run_script "kube-prom-stack/instalar-kube-prom-stack.sh" "Kube-Prom-Stack"
            ;;
        q|Q)
            echo "Saliendo..."
            break # Rompe el bucle while y termina el script
            ;;
        *)
            echo "Opción no válida. Por favor, intenta de nuevo."
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done