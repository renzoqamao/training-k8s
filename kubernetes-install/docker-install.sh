#!/bin/bash
# install-docker.sh
# Script para instalar Docker Engine y Docker Compose (plugin v2) en Ubuntu

set -euo pipefail

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${YELLOW}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[OK]${NC}    $*"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
}

install_prereqs() {
    log "Instalando paquetes previos (apt-transport-https, ca-certificates, curl, gnupg, lsb-release)…"
    apt-get update -qq
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    success "Dependencias instaladas"
}

add_docker_repo() {
    log "Añadiendo clave GPG de Docker y repositorio oficial…"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    success "Repositorio de Docker agregado"
}

install_docker() {
    log "Instalando Docker Engine y componentes…"
    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    success "Docker Engine y Docker Compose instalados"
}

enable_and_start() {
    log "Habilitando y arrancando el servicio Docker…"
    systemctl enable docker --now
    success "Servicio Docker activo"
}

verify_installation() {
    log "Verificando instalación de Docker…"
    docker --version
    log "Verificando instalación de Docker Compose (plugin)…"
    docker compose version
    success "Instalación verificada"
}

main() {
    check_root
    install_prereqs
    add_docker_repo
    install_docker
    enable_and_start
    verify_installation
}

main "$@"
