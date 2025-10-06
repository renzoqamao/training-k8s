#!/bin/bash
# k8s-worker.sh - Script para configurar nodos trabajadores de Kubernetes

# Verificar si necesitamos información del maestro
if [ -z "$MASTER_IP" ] || [ -z "$MASTER_HOSTNAME" ]; then
    # Intentar cargar desde archivo si existe
    if [ -f "/tmp/master_info.sh" ]; then
        log_info "Cargando información del maestro desde archivo..."
        source /tmp/master_info.sh
    else
        echo -e "${RED}ERROR: No se encontró información del nodo maestro${NC}"
        echo "Opciones:"
        echo "1. Ejecuta con variables: MASTER_IP=x.x.x.x MASTER_HOSTNAME=nombre ./k8s-worker.sh"
        echo "2. Copia el archivo master_info.sh desde el maestro"
        exit 1
    fi
fi

# Cargar configuración y funciones comunes
source ./k8s-common.sh

# Verificar que estamos en un nodo trabajador
if [[ "$CURRENT_HOSTNAME" == *"master"* ]]; then
    log_warning "Este sistema parece ser un nodo maestro (hostname: $CURRENT_HOSTNAME)"
    read -p "¿Deseas continuar de todos modos? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Buscar archivo de comando join
find_join_command() {
    local join_file=""
    
    # Buscar en ubicaciones comunes
    if [ -f "/tmp/kubeadm_join_command.sh" ]; then
        join_file="/tmp/kubeadm_join_command.sh"
    elif [ -f "./kubeadm_join_command.sh" ]; then
        join_file="./kubeadm_join_command.sh"
    elif [ -f "$1" ]; then
        join_file="$1"
    fi
    
    echo "$join_file"
}

# Ejecutar configuración común
run_common_setup

# Configurar hostname del trabajador (opcional)
configure_worker_hostname() {
    log "Verificando hostname del nodo trabajador..."
    log_info "Hostname actual: $CURRENT_HOSTNAME"
    
    # Si se proporciona un hostname diferente como parámetro
    if [ -n "$1" ] && [ "$1" != "$CURRENT_HOSTNAME" ]; then
        log_warning "Se proporcionó un hostname diferente: $1"
        read -p "¿Deseas cambiar el hostname a $1? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            hostnamectl set-hostname "$1"
            exec bash
            log_success "Hostname cambiado a: $1"
        fi
    fi
}

# Unir al cluster
join_cluster() {
    log "Buscando comando para unirse al cluster..."
    
    local join_file=$(find_join_command "$1")
    
    if [ -z "$join_file" ] || [ ! -f "$join_file" ]; then
        log_error "No se encontró el archivo con el comando join"
        log_error "Asegúrate de copiar kubeadm_join_command.sh desde el maestro"
        exit 1
    fi
    
    log_info "Usando comando join desde: $join_file"
    log "Uniéndose al cluster Kubernetes..."
    
    # Ejecutar comando join
    bash "$join_file" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Nodo unido al cluster correctamente"
    else
        log_error "Error al unir el nodo al cluster"
        exit 1
    fi
}

# Verificar conexión con el maestro
verify_connection() {
    log "Verificando conexión con el nodo maestro..."
    log_info "Intentando conectar con: $MASTER_HOSTNAME ($MASTER_IP)"
    
    # Verificar por IP primero
    if ping -c 3 "$MASTER_IP" >> "$LOG_FILE" 2>&1; then
        log_success "Conexión con nodo maestro establecida (IP: $MASTER_IP)"
    else
        log_error "No se puede conectar con el nodo maestro por IP: $MASTER_IP"
        exit 1
    fi
    
    # Verificar por hostname
    if ping -c 3 "$MASTER_HOSTNAME" >> "$LOG_FILE" 2>&1; then
        log_success "Resolución de hostname correcta: $MASTER_HOSTNAME"
    else
        log_warning "No se puede resolver el hostname $MASTER_HOSTNAME"
        log_warning "Verifica el archivo /etc/hosts"
    fi
}

# Verificar estado del nodo
verify_node_status() {
    log "Verificando estado del nodo trabajador..."
    
    # Verificar que kubelet esté activo
    if systemctl is-active --quiet kubelet; then
        log_success "Kubelet está activo y funcionando"
    else
        log_error "Kubelet no está activo"
        systemctl status kubelet >> "$LOG_FILE" 2>&1
    fi
    
    # Mostrar logs de kubelet para verificación
    log_info "Últimas líneas del log de kubelet:"
    journalctl -u kubelet -n 20 --no-pager >> "$LOG_FILE" 2>&1
}

# Función principal del trabajador
main() {
    log "=== Iniciando configuración del nodo trabajador ==="
    log_info "Configuración detectada:"
    log_info "  - IP del worker: $CURRENT_IP"
    log_info "  - Hostname del worker: $CURRENT_HOSTNAME"
    log_info "  - IP del master: $MASTER_IP"
    log_info "  - Hostname del master: $MASTER_HOSTNAME"
    
    # Parámetros opcionales
    local custom_hostname="$1"
    local join_file="$2"
    
    configure_worker_hostname "$custom_hostname"
    verify_connection
    join_cluster "$join_file"
    verify_node_status
    
    log_success "=== Configuración del nodo trabajador completada ==="
    log_info "El nodo se ha unido al cluster correctamente"
    log_info "Verifica desde el maestro con: kubectl get nodes"
}

# Mostrar ayuda
show_help() {
    echo "Uso: $0 [hostname-personalizado] [archivo-join]"
    echo ""
    echo "Opciones:"
    echo "  hostname-personalizado  Nuevo hostname para el worker (opcional)"
    echo "  archivo-join           Ruta al archivo con comando join (opcional)"
    echo ""
    echo "Ejemplos:"
    echo "  # Usar configuración automática"
    echo "  sudo ./k8s-worker.sh"
    echo ""
    echo "  # Especificar hostname personalizado"
    echo "  sudo ./k8s-worker.sh k8s-worker-node-2"
    echo ""
    echo "  # Especificar archivo join"
    echo "  sudo ./k8s-worker.sh '' /custom/path/join.sh"
    echo ""
    echo "Variables de entorno requeridas:"
    echo "  MASTER_IP       IP del nodo maestro"
    echo "  MASTER_HOSTNAME Hostname del nodo maestro"
}

# Procesar argumentos
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@"