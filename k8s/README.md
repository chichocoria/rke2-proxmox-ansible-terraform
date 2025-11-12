# Kubernetes - Despliegue de Servicios y Aplicaciones

Este directorio contiene todos los manifiestos de Kubernetes, scripts y valores de Helm necesarios para desplegar la pila de software completa sobre el clúster RKE2.

El despliegue está orquestado a través de un menú interactivo, `menu-install-k8sapps.sh`, que guía la instalación de los componentes en el orden correcto, asegurando que las dependencias se cumplan.

## 🚀 Arquitectura de Ingress (Zero Trust)

Este clúster implementa una arquitectura **Zero Trust** pura, eliminando la necesidad de un balanceador de carga externo (como MetalLB) o de abrir puertos en el router.

El flujo de tráfico es el siguiente:

1.  **Tráfico Externo:** Un usuario accede a `https://avatares2.chicho.com.ar`.
2.  **Cloudflare:** Cloudflare recibe la petición y la envía a través del **Cloudflare Tunnel** (Túnel Argo).
3.  **Pod `cloudflared`:** El pod del túnel, que corre dentro del clúster, recibe el tráfico. Este pod es el único componente con una conexión saliente a Cloudflare.
4.  **Enrutamiento Interno (del Túnel):** El túnel está configurado (vía Terraform) para reenviar todo el tráfico al servicio interno del Gateway: `https://nginx-gateway.nginx-gateway.svc.cluster.local:443`.
5.  **NGINX Gateway Fabric:** El NGINX Gateway recibe la petición. Consulta su recurso `Gateway` (`gateway-principal-443.yaml`) y ve que debe manejar el TLS.
6.  **Cert-Manager:** El Gateway usa un certificado (`gateway-tls-cert`) que es automáticamente solicitado y renovado por **Cert-Manager** usando el `ClusterIssuer` `letsencrypt-prod` (vía desafío DNS-01 contra la API de Cloudflare).
7.  **Enrutamiento a Servicios:** El Gateway busca una `HTTPRoute` que coincida con el *hostname* `avatares2.chicho.com.ar`. Encuentra la ruta, que le indica enviar el tráfico al `Service` de la aplicación (`web` en el namespace `avatares`).

## Componentes Principales (Menú)

El script `menu-install-k8sapps.sh` proporciona el orden de instalación recomendado.

### Infraestructura Base (Opciones 1-3)

1.  **Nginx Fabric Gateway:**

      * **Qué hace:** Instala la implementación de `Gateway API` de NGINX, que actúa como el controlador de ingreso central.
      * **Archivos clave:** `instalar-nginx-fabric-gateway.sh`, `gateway-principal-443.yaml`.
      * **Nota:** `gateway-principal-443.yaml` define los *listeners* HTTP y HTTPS para `*.chicho.com.ar` y se vincula con Cert-Manager.

2.  **Cert-Manager:**

      * **Qué hace:** Instala Cert-Manager vía Helm y aplica los `ClusterIssuers` (Staging y Prod).
      * **Archivos clave:** `instalar-cert-manager.sh`, `cluster-issuer.yaml`.
      * **Seguridad:** El script te pide de forma segura (con `read -s`) tu **Token de API de Cloudflare** (con permisos de DNS) y lo guarda directamente en un secreto de Kubernetes (`cloudflare-api-token-secret`) sin escribirlo en disco.

3.  **Cloudflare Tunnel:**

      * **Qué hace:** Despliega los pods de `cloudflared` que conectan el clúster a Cloudflare.
      * **Archivos clave:** `cloudflared-deployment.yaml`.
      * **Seguridad:** El menú te pide de forma segura tu **Token del Túnel** (no el Token de API) y crea el secreto `cloudflared-token` que el deployment necesita.

### Aplicaciones y Monitoreo (Opciones 4-9)

4.  **Kite:**

      * Instala un dashboard ligero para Kubernetes y lo expone en `kite.chicho.com.ar`.

5.  **Avatares (API + Web):**

      * Despliega la aplicación personalizada "Avatares" (compuesta por un backend `api` y un frontend `web`) y la expone en `avatares2.chicho.com.ar`.

6.  **App-Test:**

      * Una aplicación simple de "hello world" para probar el enrutamiento de Gateway en `hellogwtest443.chicho.com.ar`.

7.  **Kube-Prom-Stack (Prometheus/Grafana/Loki):**

      * **Qué hace:** Instala una pila de monitoreo completa.
      * **Archivos clave:** `instalar-kube-prom-stack.sh`, `prometheus-stack.yaml`.
      * **Dependencia:** El archivo `prometheus-stack.yaml` está configurado para usar `storageClassName: longhorn`, asegurando que Prometheus, Grafana y Alertmanager usen almacenamiento persistente.
      * **Ingress:** Expone Grafana en `monitoreo-avatares2.chicho.com.ar`.
      * **Loki:** El script también instala la pila de Loki (para logs) usando `longhorn` como almacenamiento.

8.  **Longhorn:**

      * **Qué hace:** Instala el sistema de almacenamiento en bloque distribuido. Es el `StorageClass` por defecto para los servicios con estado (como Prometheus).
      * **Archivos clave:** `instalar-longhorn-helm.sh`.

9.  **ArgoCD:**

      * Instala ArgoCD para la implementación de GitOps (aunque las rutas de ingreso no están en este directorio).
      * **Archivos clave:** `instalar-argocd-helm.sh`.

## Cómo Empezar

1.  Asegúrate de tener tu `kubeconfig` apuntando al clúster RKE2 (Ansible debió configurar esto).

2.  Navega al directorio `k8s/`.

3.  Ejecuta el menú:

    ```sh
    bash menu-install-k8sapps.sh
    ```

4.  Sigue las opciones del menú en orden numérico (del 1 al 9) para un despliegue completo. El script registrará toda la salida en un archivo dentro del directorio `logs/`.