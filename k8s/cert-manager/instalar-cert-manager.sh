#!/bin/bash
#Antes de instalar Cert-Manager en su clúster a través de Helm, creará un espacio de nombres para él:
kubectl create namespace cert-manager

##Deberá agregar el repositorio Jetstack Helm a Helm, que aloja el gráfico Cert-Manager. Para hacer esto, ejecute el siguiente comando:
helm repo add jetstack https://charts.jetstack.io

##Actualizar helm
helm repo update

##Finalmente, instale Cert-Manager en el cert-managerespacio de nombres ejecutando el siguiente comando:
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true \
  --set crds.enabled=truesleep 30

##Despliégalo con kubectl:
kubectl apply -f ~/proyecto_final_cf/k8s/cert-manager/cluster-issuert.yaml

