
# Ansible - Instalación del Clúster RKE2

Este directorio contiene los playbooks de Ansible necesarios para convertir las VMs (creadas por Terraform) en un clúster de RKE2 funcional.

El proceso está diseñado para ser ejecutado con un solo script (`deploy-cluster.sh`) que orquesta toda la instalación y configuración del clúster.

## Pre-requisitos

1.  **Infraestructura:** Las 3 VMs de Proxmox (1 master, 2 workers) deben estar creadas (vía Terraform) y accesibles por red.
2.  **Conectividad SSH:** El equipo donde ejecutes Ansible (tu "controlador") debe tener acceso SSH a las 3 VMs. Asegúrate de que tu clave SSH pública esté en las VMs (Terraform ya se encargó de esto) y tu clave privada esté en tu máquina local.
3.  **Inventario (`hosts`):** El archivo `hosts` debe estar actualizado con las IPs correctas de las VMs.
4.  **Ansible:** Debes tener Ansible instalado en tu máquina local.

## Estructura de Archivos

```
ansible/
├── ansible.cfg             # Configuración de Ansible (define usuario y path de inventario)
├── deploy-cluster.sh       # Script principal para ejecutar todos los playbooks en orden
├── hosts                   # Archivo de inventario con los grupos [master] y [worker]
├── playbooks/
│   ├── 01-puestaapunto.yaml  # Prepara los nodos con dependencias
│   ├── 02-install-rke2-master.yaml # Instala RKE2 en el nodo master
│   ├── 03-install-rke2-nodes.yaml  # Instala RKE2 en los nodos worker y los une al clúster
│   └── pruebanodos.yaml      # (Archivo de prueba, no usado en el deploy principal)
└── scripts/
    ├── add-hosts-to-hostsfile.sh # Añade IPs a /etc/hosts en cada VM
    └── modify_cloudcgf_file.sh   # Comenta una línea en cloud.cfg para evitar reseteos
```

## Configuración

### 1\. Archivo `hosts`

Este es el archivo más importante que debes verificar. Asegúrate de que las IPs coincidan con las VMs creadas por Terraform.

```ini
[master]
server ansible_host=192.168.52.104 ...

[worker]
node1 ansible_host=192.168.52.102 ...
node2 ansible_host=192.168.52.103 ...
```

### 2\. Archivo `ansible.cfg`

Define el usuario remoto (`darioc`) y el nombre del archivo de inventario (`hosts`).

```ini
[defaults]
remote_user = darioc              # Usuario SSH para conectarse
inventory = hosts                 # Path al archivo de inventario
```

## Flujo de Ejecución (`deploy-cluster.sh`)

El script `deploy-cluster.sh` ejecuta los playbooks en un orden estricto para garantizar un despliegue correcto:

### Paso 1: `01-puestaapunto.yaml`

Este playbook se ejecuta en **todos** los nodos (`hosts: all`) y realiza las siguientes tareas de preparación:

  * Verifica la conectividad (ping).
  * Actualiza todos los paquetes del sistema (apt upgrade).
  * Ejecuta `add-hosts-to-hostsfile.sh` para que los nodos puedan resolverse por nombre internamente.
  * Ejecuta `modify_cloudcgf_file.sh` para evitar que cloud-init resetee el hostname.
  * Instala dependencias clave: `docker.io`, `docker-compose`, `open-iscsi` (para Longhorn), `jq` y `nfs-common`.

### Paso 2: `02-install-rke2-master.yaml`

Este playbook se ejecuta solo en el nodo `master` y:

  * Descarga e instala RKE2 (`INSTALL_RKE2_TYPE="server"`).
  * Habilita e inicia el servicio `rke2-server.service`.
  * Espera a que RKE2 genere el `kubeconfig` en `/etc/rancher/rke2/rke2.yaml`.
  * **Importante:** Descarga el `rke2.yaml` a tu máquina local, lo copia a `~/.kube/config`, y reemplaza la IP `127.0.0.1` por la IP real del master (`192.168.52.104`). Esto te da acceso `kubectl` inmediato desde tu máquina.

### Paso 3: `03-install-rke2-nodes.yaml`

Este playbook es el que une el clúster y tiene varias partes:

1.  **Instala Agente (en Workers):** Se conecta a los nodos `worker` e instala el agente de RKE2 (`INSTALL_RKE2_TYPE="agent"`).
2.  **Obtiene Token (en Master):** Se conecta al `master` y lee el token de unión desde `/var/lib/rancher/rke2/server/node-token`.
3.  **Crea Config (en Master):** Genera un archivo `config.yaml` temporal en el master con la IP del servidor y el token.
4.  **Copia Config (a Workers):** Copia el `config.yaml` desde el master (pasando por el controlador de Ansible) a la ruta `/etc/rancher/rke2/config.yaml` en todos los nodos `worker`.
    Request too long.
5.  **Inicia Agentes (en Workers):** Inicia el servicio `rke2-agent.service` en los workers. Con el archivo de configuración en su sitio, los agentes sabrán cómo encontrar y unirse al master.

## Cómo Ejecutar

Simplemente ejecuta el script principal desde el directorio `proxmox/ansible/`:

```sh
bash ./deploy-cluster.sh
```