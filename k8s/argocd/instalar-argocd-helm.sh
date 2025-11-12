#!/bin/bash

# Verifica si Helm está instalado
if ! command -v helm &> /dev/null
then
    echo "Helm no está instalado. Por favor, instala Helm primero."
    exit 1
fi

## 1 - Create a namespace for ArgoCD:
kubectl create namespace argocd

## 2 - Install the ArgoCD Helm chart:
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd
sleep 30
## 3 - Verify that ArgoCD is running:
kubectl get pods -n argocd

# Obtener la contraseña inicial del usuario admin
echo "La contraseña inicial del usuario admin es:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo "ArgoCD instalado. El servicio 'argocd-server' se ejecuta como ClusterIP."
echo "¡Recuerda aplicar la HTTPRoute si es que necesitas exponerlo!"