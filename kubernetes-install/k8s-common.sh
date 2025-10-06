#!/bin/bash
# k8s-common.sh - Script común para todos los nodos de Kubernetes

# Cargar configuración
source ./config.sh

# Validar configuración antes de continuar
if ! validate_config; then
    echo -e "${RED}Error en la configuración. Abortando.${NC}"
    exit 1
fi

# Función para logs
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Crear directorio de logs
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "=== Iniciando instalación de Kubernetes ==="
    log "Fecha: $(date)"
    log "Hostname: $(hostname)"
    log "IP: $(hostname -I | awk '{print $1}')"
    log "Sistema: $(lsb_release -d | cut -f2)"
    log_info "Configuración detectada:"
    log_info "  - IP actual: $CURRENT_IP"
    log_info "  - Hostname actual: $CURRENT_HOSTNAME"
}

# Paso 1: Configurar archivo hosts
configure_hosts() {
    log "Configurando archivo /etc/hosts..."
    
    # Backup del archivo original
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)
    
    # Para el nodo maestro
    if [[ "$CURRENT_HOSTNAME" == *"master"* ]]; then
        # Si conocemos los workers, agregarlos
        if [ -n "$WORKER1_IP" ] && [ -n "$WORKER1_HOSTNAME" ]; then
            grep -q "$WORKER1_IP $WORKER1_HOSTNAME" /etc/hosts || echo "$WORKER1_IP $WORKER1_HOSTNAME" >> /etc/hosts
            log_info "Agregado worker: $WORKER1_IP $WORKER1_HOSTNAME"
        else
            log_warning "No se especificó información del worker. Deberás agregarla manualmente."
        fi
    else
        # Para nodos worker, necesitamos la info del master
        if [ -z "$MASTER_IP" ] || [ -z "$MASTER_HOSTNAME" ]; then
            log_error "Para nodos worker, debes especificar MASTER_IP y MASTER_HOSTNAME"
            log_error "Ejecuta: export MASTER_IP=<ip-del-master> MASTER_HOSTNAME=<hostname-del-master>"
            exit 1
        fi
        grep -q "$MASTER_IP $MASTER_HOSTNAME" /etc/hosts || echo "$MASTER_IP $MASTER_HOSTNAME" >> /etc/hosts
        log_info "Agregado master: $MASTER_IP $MASTER_HOSTNAME"
    fi
    
    # Agregar entrada para este nodo si no existe
    #grep -q "$CURRENT_IP $CURRENT_HOSTNAME" /etc/hosts || echo "$CURRENT_IP $CURRENT_HOSTNAME" >> /etc/hosts
    
    # Agregar alias del control-plane endpoint (HA)
    if [ -n "$CONTROL_PLANE_ENDPOINT" ] && [ -n "$MASTER_IP" ]; then
        grep -q "$MASTER_IP $CONTROL_PLANE_ENDPOINT" /etc/hosts \
          || echo "$MASTER_IP $CONTROL_PLANE_ENDPOINT" >> /etc/hosts
        log_info "Agregado control-plane-endpoint: $MASTER_IP $CONTROL_PLANE_ENDPOINT"
    fi

    log_success "Archivo hosts configurado"
    log_info "Contenido relevante de /etc/hosts:"
    grep -E "(k8s-|master|worker)" /etc/hosts | tee -a "$LOG_FILE"
}

# Paso 2: Deshabilitar swap
disable_swap() {
    log "Deshabilitando swap..."
    
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    
    if swapon --show | grep -q swap; then
        log_error "No se pudo deshabilitar swap"
        exit 1
    else
        log_success "Swap deshabilitado correctamente"
    fi
}

# Paso 3: Cargar módulos de kernel
load_kernel_modules() {
    log "Cargando módulos de kernel necesarios..."
    
    modprobe overlay
    modprobe br_netfilter
    
    cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    # Verificar que los módulos estén cargados
    if lsmod | grep -q overlay && lsmod | grep -q br_netfilter; then
        log_success "Módulos de kernel cargados correctamente"
    else
        log_error "Error al cargar módulos de kernel"
        exit 1
    fi
}

# Paso 4: Configurar parámetros de red
configure_networking() {
    log "Configurando parámetros de red IPv4..."
    
    cat <<EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    
    sysctl --system >> "$LOG_FILE" 2>&1
    
    log_success "Parámetros de red configurados"
}

# Paso 5: Instalar Docker
install_docker() {
    log "Instalando Docker..."
    
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get install -y docker.io >> "$LOG_FILE" 2>&1
    
    if systemctl is-active --quiet docker; then
        log_success "Docker instalado y activo"
    else
        systemctl start docker
        systemctl enable docker
        log_success "Docker instalado, iniciado y habilitado"
    fi
    
    docker version >> "$LOG_FILE" 2>&1
}

# Instalando containerd
install_containerd() {
    log "Instalando containerd..."
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get install -y containerd >> "$LOG_FILE" 2>&1
}
# Configurar containerd
configure_containerd() {
    log "Configurando containerd..."
    
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl restart containerd.service
    
    if systemctl is-active --quiet containerd; then
        log_success "Containerd configurado y activo"
    else
        log_error "Error al configurar containerd"
        exit 1
    fi
}

add_docker_repository() {
    log "Agregando repositorio oficial de Docker..."

    mkdir -p /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

    log_success "Repositorio y clave GPG de Docker añadidos correctamente"
}

# Paso 6: Instalar componentes de Kubernetes
install_kubernetes() {
    log "Instalando componentes de Kubernetes..."
    
    # Instalar paquetes prerequisitos
    apt-get install -y curl ca-certificates apt-transport-https >> "$LOG_FILE" 2>&1
    

    # Agregar clave GPG de Kubernetes
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Agregar repositorio de Kubernetes
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    
    # Actualizar e instalar
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get install -y kubelet kubeadm kubectl >> "$LOG_FILE" 2>&1
    
    # Verificar instalación
    if command -v kubeadm &> /dev/null && command -v kubelet &> /dev/null && command -v kubectl &> /dev/null; then
        log_success "Componentes de Kubernetes instalados correctamente"
        kubeadm version >> "$LOG_FILE"
        kubectl version --client >> "$LOG_FILE" 2>&1
    else
        log_error "Error al instalar componentes de Kubernetes"
        exit 1
    fi
}

# Función principal para ejecutar todas las tareas comunes
run_common_setup() {
    check_root
    setup_logging
    show_config
    
    log "=== Ejecutando configuración común para todos los nodos ==="
    
    configure_hosts
    disable_swap
    load_kernel_modules
    configure_networking
    #install_docker
    add_docker_repository
    install_containerd
    configure_containerd
    install_kubernetes
    
    log_success "=== Configuración común completada ==="
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_common_setup
fi