#!/bin/sh

# Provision infrastructure
terraform apply -auto-approve

# Wait for 30s
sleep 30s

# Deploy k3s
ansible-playbook 01-k3s-cluster.yml

# Deploy Longhorn
ansible-playbook 02-longhorn.yml

# Deploy Portainer
ansible-playbook 03-portainer.yml