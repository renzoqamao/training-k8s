#!/bin/bash
# config.sh - Configuración para el cluster de Kubernetes

# Configuración de red
export POD_NETWORK_CIDR="100.200.0.0/16"
export KUBERNETES_VERSION="v1.31"

# Función para obtener la IP principal del sistema
get_primary_ip() {
    # Intenta diferentes métodos para obtener la IP
    # Método 1: hostname -I
    local ip=$(hostname -I | awk '{print $1}')
    
    # Método 2: ip route (si el método 1 falla)
    if [ -z "$ip" ]; then
        ip=$(ip route get 8.8.8.8 | awk '/src/ {print $7}')
    fi
    
    # Método 3: ifconfig (si está disponible)
    if [ -z "$ip" ] && command -v ifconfig &> /dev/null; then
        ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
    fi
    
    echo "$ip"
}

# Detectar si este es el nodo maestro o trabajador basándose en el hostname actual
CURRENT_HOSTNAME=$(hostname)
CURRENT_IP=$(get_primary_ip)

# Configuración de nodos - Detección automática
if [[ "$CURRENT_HOSTNAME" == *"master"* ]]; then
    # Este es el nodo maestro
    export MASTER_IP="$CURRENT_IP"
    export MASTER_HOSTNAME="$CURRENT_HOSTNAME"
    echo "Detectado como nodo maestro: $MASTER_HOSTNAME ($MASTER_IP)"
else
    # Este es un nodo trabajador
    export WORKER_IP="$CURRENT_IP"
    export WORKER_HOSTNAME="$CURRENT_HOSTNAME"
    echo "Detectado como nodo trabajador: $WORKER_HOSTNAME ($WORKER_IP)"
fi

# Variables que deben ser configuradas manualmente o pasadas como parámetros
# Si estás en el maestro, necesitas definir los workers
# Si estás en un worker, necesitas definir el maestro

# Valores por defecto (se pueden sobrescribir con variables de entorno)
export MASTER_IP="${MASTER_IP:-}"
export MASTER_HOSTNAME="${MASTER_HOSTNAME:-k8s-master-node}"

export WORKER1_IP="${WORKER1_IP:-}"
export WORKER1_HOSTNAME="${WORKER1_HOSTNAME:-k8s-worker-node-1}"

# ————— HA control-plane endpoint —————
export CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT:-k8scp}"
export CONTROL_PLANE_PORT="${CONTROL_PLANE_PORT:-6443}"

# Función para validar la configuración
validate_config() {
    local is_valid=true
    
    if [ -z "$CURRENT_IP" ]; then
        echo "ERROR: No se pudo detectar la IP del sistema actual"
        is_valid=false
    fi
    
    if [ -z "$CURRENT_HOSTNAME" ]; then
        echo "ERROR: No se pudo detectar el hostname del sistema actual"
        is_valid=false
    fi
    
    if [ "$is_valid" = false ]; then
        return 1
    fi
    
    return 0
}

# Configuración de logs
export LOG_DIR="/var/log/kubernetes-install"
export LOG_FILE="${LOG_DIR}/k8s-install-$(date +%Y%m%d-%H%M%S).log"

# Colores para output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Mostrar configuración detectada
show_config() {
    echo -e "${BLUE}=== Configuración detectada ===${NC}"
    echo "Hostname actual: $CURRENT_HOSTNAME"
    echo "IP actual: $CURRENT_IP"
    echo "Rol detectado: $(if [[ "$CURRENT_HOSTNAME" == *"master"* ]]; then echo "MASTER"; else echo "WORKER"; fi)"
    echo -e "${BLUE}==============================${NC}"
}

# Si se ejecuta directamente, mostrar la configuración
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_config
    validate_config
fi