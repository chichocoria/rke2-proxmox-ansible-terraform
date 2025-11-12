#!/bin/bash

#================================================================
#             SCRIPT PARA CREAR TEMPLATE UBUNTU 24.04 
#================================================================

# --- Configuración Principal (Modificar esto según tu entorno) ---

# ID para la nueva VM/Template
VMID="9000"

# Nombre del template
VMNAME="ubuntu-2404-ci"

# Usuario que creará Cloud-Init
# Cambiar por tu usuario
CI_USER="mi_usuario"

# Ruta al archivo de claves SSH públicas (si no existe crearlo y pegar tu clave pública)
SSH_KEYS_FILE="/root/authorized_keys"

# --- Configuración de la VM---
MEMORY="2048"
CORES="2"
BRIDGE="vmbr0"
DISK_SIZE="+4G"
BALLOON="1024" # Memoria mínima

# --- Configuración de Almacenamiento y Discos ---

# Storage pool de Proxmox donde se guardarán los discos de la VM
STORAGE_POOL="lvm-vms"

# Directorio en Proxmox donde se descargará la imagen cloud
# (Asegúrate de que esta ruta exista y tenga espacio)
IMAGE_DIR="/root"

# --- Configuración de la Imagen Cloud ---
IMAGE_NAME="noble-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/$IMAGE_NAME"
IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME"

# --- Fin de la Configuración ---


# Salir inmediatamente si un comando falla
set -eo pipefail

echo "### Iniciando creación de template $VMNAME (ID: $VMID) ###"

# 1. Verificar que el archivo de claves SSH existe
if [ ! -f "$SSH_KEYS_FILE" ]; then
    echo "¡Error! El archivo de claves SSH no se encuentra en: $SSH_KEYS_FILE"
    echo "Por favor, crea este archivo con tu clave pública SSH y vuelve a intentarlo."
    exit 1
fi
echo "Archivo de claves SSH encontrado en $SSH_KEYS_FILE."

# 2. Descargar la imagen (si no existe)
echo "--- Paso 1: Verificando imagen de Ubuntu 24.04 ---"
mkdir -p $IMAGE_DIR # Crear directorio si no existe
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Descargando imagen desde $IMAGE_URL..."
    wget -O $IMAGE_PATH $IMAGE_URL
else
    echo "La imagen ya existe en $IMAGE_PATH. Saltando descarga."
fi

# 3. Crear la VM
echo "--- Paso 2: Creando VM $VMID ---"
qm create $VMID --name $VMNAME --memory $MEMORY --cores $CORES --net0 virtio,bridge=$BRIDGE

# 4. Importar el disco
echo "--- Paso 3: Importando disco al storage '$STORAGE_POOL' ---"
# El artículo usa 'vm_nvme' como storage
qm importdisk $VMID $IMAGE_PATH $STORAGE_POOL

# 5. Configurar el hardware de la VM
echo "--- Paso 4: Configurando hardware y Cloud-Init ---"

# Configurar disco y booteo (basado en la sintaxis del artículo)
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE_POOL:vm-$VMID-disk-0,cache=writeback,discard=on,ssd=1
qm set $VMID --boot c --bootdisk scsi0

# Añadir drive de Cloud-Init
# El artículo lo pone en scsi1
qm set $VMID --scsi1 $STORAGE_POOL:cloudinit

# Configurar QEMU Guest Agent
qm set $VMID --agent enabled=1

# Redimensionar el disco
qm resize $VMID scsi0 $DISK_SIZE

# Configuración de consola
qm set $VMID --serial0 socket --vga serial0

# Configuración de CPU y OS
qm set $VMID --cpu cputype=host
qm set $VMID --ostype l26

# Configuración de memoria (ballooning)
qm set $VMID --balloon $BALLOON

# 6. Configurar parámetros de Cloud-Init
echo "--- Paso 5: Aplicando configuración Cloud-Init ---"
qm set $VMID --ciupgrade 1
qm set $VMID --ciuser $CI_USER
qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --nameserver 1.1.1.1 # DNS (se podria cargar otro DNS, ej: 8.8.8.8)
qm set $VMID --sshkeys $SSH_KEYS_FILE

# 7. Convertir a template
echo "--- Paso 6: Convirtiendo VM a template ---"
qm template $VMID

echo "---"
echo "✅ ¡Éxito! Template $VMNAME (ID: $VMID) creado."
echo "Usuario Cloud-Init: $CI_USER"
echo "Claves SSH desde: $SSH_KEYS_FILE"
echo "---"