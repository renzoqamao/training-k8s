#!/bin/bash
# k8s-master.sh - Script para configurar el nodo maestro de Kubernetes

# Ejecutar configuración común
source ./k8s-common.sh

# Verificar que estamos en el nodo maestro
if [[ "$CURRENT_HOSTNAME" != *"master"* ]]; then
    log_warning "Este sistema no parece ser un nodo maestro (hostname: $CURRENT_HOSTNAME)"
    read -p "¿Deseas continuar de todos modos? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

run_common_setup

# Configurar hostname específico del maestro (ya no es necesario si usamos el actual)
configure_master_hostname() {
    log "Verificando hostname del nodo maestro..."
    log_info "Hostname actual: $CURRENT_HOSTNAME"
    
    # Opcional: cambiar hostname si se desea
    if [ -n "$MASTER_HOSTNAME" ] && [ "$MASTER_HOSTNAME" != "$CURRENT_HOSTNAME" ]; then
        log_warning "El hostname configurado ($MASTER_HOSTNAME) difiere del actual ($CURRENT_HOSTNAME)"
        read -p "¿Deseas cambiar el hostname a $MASTER_HOSTNAME? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            hostnamectl set-hostname "$MASTER_HOSTNAME"
            exec bash
            log_success "Hostname cambiado a: $MASTER_HOSTNAME"
        fi
    fi
}

# Inicializar cluster Kubernetes
initialize_cluster() {
    log "Inicializando cluster Kubernetes..."
    log "CIDR de red de pods: $POD_NETWORK_CIDR"
    log "IP del maestro: $MASTER_IP"
    log "Control plane endpoint: $CONTROL_PLANE_ENDPOINT:$CONTROL_PLANE_PORT"
    # Inicializar cluster con la IP detectada
    #kubeadm init --apiserver-advertise-address="$MASTER_IP" --pod-network-cidr="$POD_NETWORK_CIDR" 2>&1 | tee -a "$LOG_FILE"
    # Inicializar cluster usando el DNS k8scp como endpoint HA
    kubeadm init \
      --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT:$CONTROL_PLANE_PORT" \
      --pod-network-cidr="$POD_NETWORK_CIDR" \
      --upload-certs \
      2>&1 | tee -a "$LOG_FILE"


    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Cluster inicializado correctamente"
    else
        log_error "Error al inicializar el cluster"
        exit 1
    fi
    
    # Guardar comando join para los workers
    log "Guardando comando join para nodos trabajadores..."
    kubeadm token create --print-join-command > /root/kubeadm_join_command.sh
    chmod +x /root/kubeadm_join_command.sh
    log_success "Comando join guardado en /root/kubeadm_join_command.sh"
    
    # También guardar info del master para los workers
    cat > /root/master_info.sh <<EOF
#!/bin/bash
# Información del nodo maestro para configurar workers
export MASTER_IP="$MASTER_IP"
export MASTER_HOSTNAME="$MASTER_HOSTNAME"
EOF
    chmod +x /root/master_info.sh
    log_info "Información del maestro guardada en /root/master_info.sh"
}

# Configurar kubectl para el usuario
configure_kubectl() {
    log "Configurando kubectl para el usuario..."
    
    # Configurar para root
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Si hay un usuario no-root, configurar también para él
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
        mkdir -p "$USER_HOME/.kube"
        cp -i /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
        chown $SUDO_USER:$SUDO_USER "$USER_HOME/.kube/config"
        log_success "kubectl configurado para usuario $SUDO_USER"
    fi
    
    log_success "kubectl configurado correctamente"
}

# Instalar Calico network plugin
install_calico() {
    log "Instalando Calico network plugin..."
    
    # Crear operador de Calico
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml >> "$LOG_FILE" 2>&1
    
    # Descargar y modificar custom resources
    curl -s https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -o custom-resources.yaml
    sed -i "s|cidr: 192\.168\.0\.0/16|cidr: $POD_NETWORK_CIDR|g" custom-resources.yaml
    
    # Aplicar configuración
    kubectl create -f custom-resources.yaml >> "$LOG_FILE" 2>&1
    
    log_success "Calico instalado correctamente"
    
    # Esperar a que los pods estén listos
    log "Esperando a que los pods de Calico estén listos..."
    sleep 30
    kubectl get pods -n calico-system >> "$LOG_FILE" 2>&1
}

install_cilium(){
    # instalar cilium con helm
    log "Instalando Cilium..."
    helm repo add cilium https://helm.cilium.io/
    helm repo update >> "$LOG_FILE" 2>&1
    helm template cilium cilium/cilium --version 1.16.1 --namespace kube-system > cilium.yaml
    kubectl apply -f cilium.yaml >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_success "Cilium instalado correctamente"
    else
        log_error "Error al instalar Cilium"
        exit 1
    fi
    log "Esperando a que los pods de Cilium estén listos..."
    sleep 30
    kubectl get pods -n kube-system >> "$LOG_FILE" 2>&1
    log_success "Pods de Cilium listos" 
}

install_helm(){
    #install helm
    log "Instalando Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_success "Helm instalado correctamente"
    else
        log_error "Error al instalar Helm"
        exit 1
    fi
}

# Verificar estado del cluster
verify_cluster() {
    log "Verificando estado del cluster..."
    
    kubectl get nodes >> "$LOG_FILE" 2>&1
    kubectl get pods -A >> "$LOG_FILE" 2>&1
    
    # Verificar que el nodo maestro esté Ready
    if kubectl get nodes | grep -q "Ready"; then
        log_success "Nodo maestro está Ready"
    else
        log_warning "Nodo maestro aún no está Ready"
    fi
}

# Mostrar información para workers
show_worker_info() {
    log_info "=== Información para configurar nodos trabajadores ==="
    echo -e "${BLUE}1. Copia estos archivos a cada nodo trabajador:${NC}"
    echo "   scp /root/kubeadm_join_command.sh user@worker:/tmp/"
    echo "   scp /root/master_info.sh user@worker:/tmp/"
    echo ""
    echo -e "${BLUE}2. En cada nodo trabajador, ejecuta:${NC}"
    echo "   source /tmp/master_info.sh"
    echo "   sudo ./k8s-worker.sh"
    echo ""
    echo -e "${BLUE}3. O puedes ejecutar directamente con las variables:${NC}"
    echo "   sudo MASTER_IP=$MASTER_IP MASTER_HOSTNAME=$MASTER_HOSTNAME ./k8s-worker.sh"
}

# Función principal del maestro
main() {
    log "=== Iniciando configuración específica del nodo maestro ==="
    
    configure_master_hostname
    initialize_cluster
    configure_kubectl
    install_helm
    install_calico
    #install_cilium
    verify_cluster
    
    log_success "=== Configuración del nodo maestro completada ==="
    show_worker_info
}

# Ejecutar función principal
main
 