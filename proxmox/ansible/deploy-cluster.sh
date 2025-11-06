#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

echo "--- Iniciando el despliegue de Ansible ---"

# 1. Posicionarse en el directorio
echo "Cambiando al directorio ~/proyecto_final_cf/proxmox/ansible/ ..."
cd ~/rke2-proxmox-ansible-terraform/proxmox/ansible/

# 2. Correr el primer playbook
echo "Ejecutando: 01-puestaapunto.yaml ..."
ansible-playbook -i hosts playbooks/01-puestaapunto.yaml

# 3. Correr el segundo playbook
echo "Ejecutando: 02-install-rke2-master.yaml ..."
ansible-playbook -i hosts playbooks/02-install-rke2-master.yaml

# 4. Correr el tercer playbook
echo "Ejecutando: 03-install-rke2-nodes.yaml ..."
ansible-playbook -i hosts playbooks/03-install-rke2-nodes.yaml

echo "--- ¡Todos los playbooks se completaron exitosamente! ---"