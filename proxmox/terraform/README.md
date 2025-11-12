# Terraform - Aprovisionamiento de Infraestructura

Este directorio contiene el código de Terraform para aprovisionar la infraestructura base del clúster RKE2.

El código es responsable de dos tareas principales:

1.  **En Proxmox:** Crear las 3 máquinas virtuales (1 master, 2 workers) que formarán el clúster.
2.  **En Cloudflare:** Configurar el `Cloudflare_Tunnel` y crear los registros DNS (CNAME) necesarios para exponer los servicios del clúster.

## Pre-requisitos

Antes de ejecutar este código, asegúrate de tener:

1.  **Terraform Cloud:** Una cuenta de Terraform Cloud. El backend está configurado para usarse con la organización `avatares-devops`.

2.  **Template de Proxmox Cloud-Init:**
    Terraform necesita clonar un template de VM. Este repositorio incluye el script para crearlo.

      * **Acción Requerida:** Antes de correr Terraform, navega al directorio `proxmox/scripts/` (o donde decidas guardar el script) y ejecútalo.
      * **¡Importante\!:** Antes de ejecutarlo, revisa las variables dentro del script (como `CI_USER`, `STORAGE_POOL`, `SSH_KEYS_FILE`) para que coincidan con tu entorno Proxmox.
      * El script creará el template `ubuntu-2404-ci`, que es el valor esperado por la variable `cloudinit_template_name` en tu `terraform.tfvars`.

3.  **Proxmox:**

      * Un usuario y rol con permisos suficientes (ej. `terraform_user@pve`).
      * Un Token API para ese usuario (usado en las variables de entorno).

4.  **Cloudflare:**

      * El `zone_id` y `account_id` de tu cuenta (usados en `terraform.tfvars`).
      * Un Token API de Cloudflare con permisos para editar DNS y Túneles (usado en las variables de entorno).
      * Un **Túnel de Cloudflare ya creado**. Este Terraform *configura* un túnel existente, no lo crea desde cero. Necesitarás el `tunnel_id` (usado en `terraform.tfvars`).

## Configuración

Sigue estos pasos para configurar tu entorno antes de ejecutar Terraform.

### Paso 1: Backend de Terraform Cloud

El estado se almacena remotamente en Terraform Cloud. La primera vez que ejecutes el código en tu máquina, necesitarás iniciar sesión:

```sh
terraform login
```

Sigue las instrucciones en pantalla para autenticarte.

### Paso 2: Variables de Entorno (Credenciales)

Las credenciales sensibles deben ser expuestas como variables de entorno. El proveedor de Proxmox las leerá automáticamente (`PM_API_TOKEN_ID`, `PM_API_TOKEN_SECRET`), al igual que el proveedor de Cloudflare (`CLOUDFLARE_API_TOKEN`).

Crea un script (ej. `export-vars.sh`) o exporta las siguientes variables en tu terminal:

```sh
#!/bin/bash

# --- Credenciales de Proxmox ---
# (Recomendado: Usar el Token API)
export PM_API_TOKEN_ID="user@pve!token_id"
export PM_API_TOKEN_SECRET="api_token_secret"

# (Alternativa: Usuario y Contraseña - No recomendado para automatización)
export PM_USER="terraform_user@pve"
export PM_PASS="password"

# --- Credencial de Cloudflare ---
export CLOUDFLARE_API_TOKEN="cloudflare_api_token"
```

**Nota:** El proveedor de Proxmox priorizará el Token API si ambas (token y user/pass) están presentes.

### Paso 3: Archivo de Variables (`terraform.tfvars`)

Crea un archivo llamado `terraform.tfvars` en este mismo directorio. Este archivo contendrá las variables no sensibles específicas de tu entorno.

```hcl
# --- Configuración de Proxmox ---

# URL de tu API de Proxmox
pm_api_url = "https://192.168.1.100:8006/api2/json"

# Nombre del template Cloud-Init en Proxmox
cloudinit_template_name = "ubuntu-2404-ci"

# Nombre del nodo de Proxmox donde se desplegarán las VMs
proxmox_node = "pve"

# Tu clave SSH pública para acceder a las VMs
ssh_key = "ssh-rsa AAAA..."


# --- Configuración de Cloudflare ---

# ID de la Zona (Tu dominio)
zone_id = "tu_zone_id_de_cloudflare"

# ID de tu cuenta de Cloudflare
account_id = "tu_account_id_de_cloudflare"

# ID del Túnel de Cloudflare que este código va a configurar
tunnel_id = "tu_tunnel_id_de_cloudflare"
```

## Ejecución

Una vez completada la configuración:

1.  **Inicia sesión en Terraform Cloud** (si no lo has hecho):

    ```sh
    terraform login
    ```

2.  **Inicializa Terraform**:
    Descarga los proveedores y configura el backend.

    ```sh
    terraform init
    ```

3.  **Planifica los cambios**:
    Revisa qué recursos se crearán o modificarán.

    ```sh
    terraform plan
    ```

4.  **Aplica los cambios**:
    Aprovisiona la infraestructura.

    ```sh
    terraform apply
    ```

## Recursos Creados

### Proxmox

  * **1 x VM Master** (`kubernetes-master-1`): 2 cores, 4GB RAM, 40GB disco.
  * **2 x VMs Worker** (`kubernetes-node-1`, `kubernetes-node-2`): 2 cores, 4GB RAM, 40GB disco.

### Cloudflare

  * **1 x `cloudflare_tunnel_config`**: Configura el túnel con las reglas de ingreso para `hellogwtest443`, `avatares2`, `monitoreo-avatares2` y `kite`.
  * **4 x `cloudflare_record` (CNAME)**: Crea los registros CNAME para `hellogwtest443`, `avatares2`, `monitoreo-avatares2` y `kite`, todos apuntando al túnel.