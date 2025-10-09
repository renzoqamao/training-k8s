# Tipos de aprovisionamiento

## Aprovisionamiento estático

En el aprovisionamiento estático, los administradores crean previamente los `PersistentVolume (PV)` antes de que los pods los soliciten mediante un `PersistenceVolumeClaim (PVC)`. Estos volúmenes tienen `tamaño fijo` y están vinculados a un recurso de almacenamiento ya existente. 

### HostPath

Solo para entornos locales o pruebas. No es recomendable para producción ya que esta ligado únicamente a un único nodo del cluster.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-static-hostpath
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-static-hostpath
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

```

En este caso el administrador debe crear `/mnt/data` en el nodo manualmente.

### NFS (Network file System)

En este caso los pods se conectan a un servidor NFS externo. Permite que varios pods y nodos accedan al mismo volumen (ReadWriteMany). Es muy usado en clústeres locales y on-premise. Es necesario que halla un servidor nfs externo disponible que este expuesto a la interfaz de red del clúster y exporter `/export/data`.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-static-nfs
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.1.100   # IP del servidor NFS
    path: "/export/data"
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-static-nfs
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
```
### iSCSI (Internet Small Computer System Interface)

Se conecta a un dispositivo de almacenamiento via protocolo iSCSI. Permite bloques de disco remoto como si fueran locales. Utilizado en entornos empresariales

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-static-iscsi
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  iscsi:
    targetPortal: 10.20.30.40:3260
    iqn: iqn.2001-04.com.example:storage.lun1
    lun: 0
    fsType: ext4
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-static-iscsi
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```
En este caso el administrador ya tiene configurado el servidor iSCSI con el target y el LUN.

### Volumenes tipo Cloud

En la nube se pueden utilizar volúmenes estáticos dados por el proveedor. En AWS se puede utilizar EBS.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-static-ebs
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: vol-0a1b2c3d4e5f67890   # ID creado manualmente en AWS
    fsType: ext4
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-static-ebs
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi

```

En este caso el Elastic Block Storage debe crearse manualmente previamente.

## Aprovisionamiento dinámico

### Local Path Provisioner

Crea directorios locales en nodos bajo demanda. Utilizado en desarrollo, cada vez que se crea un PVC, genera un carpeta en el nodo `(ej. /opt/local-path-provisioner/pvc-xxx)`.

Creación del StorageClass(Provisioner):

```yaml
# (Ejemplo de StorageClass para Local Path Provisioner)  localPathProvisioner.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  pathPattern: "/opt/local-path-provisioner/%s"
```

```bash
kubectl apply -f localPathProvisioner.yaml
```

Despliegue rápido con el manifiesto oficial:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl get storageclass
kubectl describe storageclass local-path
```

Ejemplo de PVC que reclama un volumen:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-local-path
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path   # StorageClass creada por Local Path Provisioner
  resources:
    requests:
      storage: 2Gi

```

> Notas importantes:
> - volumeBindingMode: WaitForFirstConsumer es recomendable en local: evita crear el volumen en un nodo distinto al que finalmente ejecutará el Pod.
> - Los volúmenes son locales al nodo; si el pod se mueve a otro nodo, el dato no lo acompaña (no es HA por sí solo). Ideal para dev/test.

### NFS Subdir External Provisioner

Usa un servidor NFS existente. Crea automaticamente subdirectorios en el servidor NFS cada que vez que un PVC lo solicita, evitando configuraciones manuales de PV. Es útil para compartir volúmenes entre nodos.

La manera más rápida de desplegar el NFS Subdir External provisioner es utilizando helm:

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace kube-system --create-namespace -f nfs-values.yaml
```

```yaml 
# nfs-values.yaml
replicaCount: 1

nfs:
  server: "192.168.1.100"   # <-- Cambia por la IP/hostname de tu NFS
  path: "/exported/path"    # <-- Cambia por el path exportado

provisioner:
  # nombre del provisioner que se usará en la StorageClass
  name: "example.com/nfs"

storageClass:
  create: true
  name: "nfs-client"
  defaultClass: false
  reclaimPolicy: Delete
  mountOptions:
    - vers=4.1
  archiveOnDelete: "false"

rbac:
  create: true

# Opcional: configurar tolerations/nodeSelector si tu NFS client debe correr en nodos concretos
# nodeAffinity: {}
# tolerations: []
```


Ejemplo de PVC que reclama un volumen:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs-dynamic
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client   # StorageClass definida para el NFS Provisioner
  resources:
    requests:
      storage: 5Gi
```

## Consideraciones

Siempre que se use NFS (estático o dinámico) es necesario que todos los nodos donde pueden correr los Pods deben tener instalado el cliente NFS( NFS-common o nfs-utils).


## Aprovisionamiento distribuido

El diseño de kubernetes es dinámico: los pods pueden moverse entre nodos, reiniciarse o escalar. Esto genera que pensemos como abordar el problema de la persistencia de datos aunque un Pod/nodo desaparezca. La solución son los volúmenes persistentes (PV), que permiten desacoplar el ciclo de vida del contenedor del ciclo de vida de los datos. Pero si el almacenamiento está en un solo nodo, existe un punto único de falló. Es por eso que existe el almacenamiento distribuido dinámico.

### ¿ Qué es almacenamiento distribuido?

Es un sistema que:
* Agrupa discos de varios nodos en un solo pool de almacenamiento.
* Replica o distribuye los datos entre nodos para evitar pérdida de información.
* Expone vólumenes lógicos que pueden montarse desde cualquier nodo del clúster.

Por defecto, kubernetes no trae un sistema de almacenamiento distribuido. Lo que hace es apoyarse en drivers CSI (Container Storage Interface) que permite integrar sistemas de almacenamiento externos.

Existen los siguientes sistemas:
- Longhorn
- Ceph
- GlusterFS
- Portworx

para:
- Aprovisionamiento dinámico de volúmenes.
- Replicación y resilencia de datos.
- Movilidad: Cualquier pod puede montar el mismo volumen desde otro nodo.

### Tipos de almacenamiento distribuido
 
* Almacenamiento basado en bloques (Rook-Ceph, Longhorn, OpenEBS)
    - Se presenta volúmenes tipo disco a los pods.
    - Ideales para base de datos y cargas de trabajo de alto rendimiento.
* Almacenamiento basado en archivos (CephFS, GlusterFS, NFS distribuido)
    - Permite que varios pods lean/escriban el mismo sistema de archivos.
    - Útiles para aplicaciones que comparten datos.
* Almacenamiento basado en objetos (MinIO, Ceph Object, S3)
    - Los pods acceden a datos vía API (HTTP/S3)
    - Bueno para backups, multimedia o big data.


### Beneficios

* Alta disponibilidad: Los datos sobreviven a la caída de nodos.
* Escalabilidad: Se agregan nodos/discos para crecer.
* Tolerancia a fallos: mediante replicación o codificación de borrado.
* Desacoplamiento de la infraestructura: los pods no dependen de un nodo físico en particular.

---

# Despliegue de almacenamiento distribuido Longhorn

Longhorn es un sistema de almacenamiento distribuido para Kubernetes que proporciona volúmenes persistentes mediante el uso de discos locales y almacenamiento en red. Permite la gestión sencilla de volúmenes, la replicación de datos para alta disponibilidad, snapshots, backups y restauraciones. Longhorn es fácil de instalar y administrar, y está diseñado para integrarse de forma nativa con Kubernetes, facilitando la gestión del almacenamiento en clústeres de contenedores.

## prerrequisitos

```bash
# En todos los nodos del cluster (prerrequisitos para longhorn)
sudo apt-get update
sudo apt-get install -y open-iscsi util-linux nfs-common

# Verificar que iscsid esté corriendo
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

validación:

```bash
sudo modprobe nfs
sudo modprobe nfsd
which iscsiadm
which mount.nfs4
showmount --version
```
* open-iscsi → Cliente iSCSI: Longhorn usa iSCSI para exponer volúmenes persistentes a los nodos. Sin este paquete, los pods no podrían montar los discos de Longhorn.

* util-linux → Conjunto de utilidades básicas de Linux (ej. mount, fdisk, lsblk).: Necesarias para gestionar discos, montar volúmenes y trabajar con almacenamiento.

* nfs-common → Cliente NFS para Linux: Longhorn lo necesita si vas a usar volúmenes RWX (ReadWriteMany) o hacer backups en NFS.

* modprobe nfs: Carga el módulo del kernel para que el cliente NFS funcione.

* modprobe nfsd: Carga el módulo del servidor NFS (necesario si un nodo actúa como servidor/exporta volúmenes).

* which iscsiadm: Verifica que la herramienta principal del cliente iSCSI (iscsiadm) está instalada. Es la que permite gestionar sesiones iSCSI.

* which mount.nfs4: Comprueba que el binario para montar sistemas de archivos NFSv4 está disponible. Necesario para RWX y backups en NFS.

* showmount --version: Confirma que el comando showmount (parte de nfs-common) está instalado y funcionando. Se usa para consultar exportaciones disponibles en un servidor NFS.

## Instalación

1. Agregamos el repositorio de longhorn

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

2. Creamos un namespace para longhorn

```bash
kubectl create namespace longhorn-system
```

3. Busca charts en un repositorio

```bash
helm search repo longhorn

NAME                    CHART VERSION   APP VERSION     DESCRIPTION
longhorn/longhorn       1.10.0          v1.10.0         Longhorn is a distributed block storage system ...
```

4. Busca charts en un ArtifactHub (catálogo público)

```bash
helm search hub longhorn
```

5. Mostrar información del chart

```bash
helm show chart longhorn/longhorn

apiVersion: v1
appVersion: v1.10.0
description: Longhorn is a distributed block storage system for Kubernetes.
home: https://github.com/longhorn/longhorn
icon: https://raw.githubusercontent.com/cncf/artwork/master/projects/longhorn/icon/color/longhorn-icon-color.png
keywords:
- longhorn
- storage
- distributed
- block
- device
- iscsi
- nfs
kubeVersion: '>=1.25.0-0'
maintainers:
- email: maintainers@longhorn.io
  name: Longhorn maintainers
name: longhorn
sources:
- https://github.com/longhorn/longhorn
- https://github.com/longhorn/longhorn-engine
- https://github.com/longhorn/longhorn-instance-manager
- https://github.com/longhorn/longhorn-share-manager
- https://github.com/longhorn/longhorn-manager
- https://github.com/longhorn/longhorn-ui
- https://github.com/longhorn/longhorn-tests
- https://github.com/longhorn/backing-image-manager
version: 1.10.0
```

6. Ver los valores configurables

```bash
helm show values longhorn/longhorn > defaultValues.yaml
```

7. Ver los templates/renderizado antes de instalar

```bash
helm template my-longhorn longhorn/longhorn --values defaultValues.yaml > my-longhorn-deploy.yaml
```

8. Instalación de longhorn en su namespace correspondiente

```bash
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --values values.yaml --debug --atomic --timeout 20m0s
```
* helm install: indica que se va a instalar un chart en kubernetes como un release.
* longhorn: es el nombre del release que le das en tu clúster. útil para luego realizar actualización o desinstalación del release.
* longhorn/longhorn: es el chart a instalar; El primer longhorn es el nombre del repositorio de Helm, el segundo es el nombre del chart dentro de ese repo.
* --namespace longhorn-system: Instala todos los objetos (Deployments, DaemonSets, CRDs, Services, etc) en el namespace longhorn-system.
* --create-namespace: Si el namespace longhorn-system no existe, entonces lo crea previamente.
* --values values.yaml: Utiliza el archivo values.yaml personalizado en lugar de los valores por defecto. Se define valores para cambiar configuraciones de los objetos.
* --debug: Muestra información detallada en la consola: manifiestos renderizados, logs de instalación y pasos de Helm.
* --atomic: Si algo falla durante la instalación, Helm deshace todo automaticamente.
* --timeout 20m0s: Tiempo máximo que helm esperará a que se creen todos los recursos. 


Mi DNS hacia mi cluster es k8scp entonces para conectarme a la interfaz de longhorn existen dos manera:
* port-forward: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80`
* a traves de un ingress & ingress controller. Para mi caso: `https://k8scp:30198/#/dashboard`


## ¿Para qué sirven múltiples StorageClasses?

Cada aplicación tiene **diferentes necesidades de almacenamiento**. Con múltiples StorageClasses puedes optimizar:

### 1. **Performance vs Redundancia**

```yaml
# StorageClass para BBDD críticas (máxima redundancia)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-critical
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "3"        # 3 copias (alta disponibilidad)
  staleReplicaTimeout: "30"    # 30 min (detecta fallos rápido)
  diskSelector: "ssd"          # Solo usa discos SSD
  nodeSelector: "storage-tier:premium"
```

**RAZÓN**: Para PostgreSQL, MySQL, Elasticsearch → máxima durabilidad

```yaml
# StorageClass para desarrollo/testing (velocidad)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-dev
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"        # 1 copia (más rápido, menos espacio)
  staleReplicaTimeout: "1440"  # 24h (no importa si tarda)
```

**RAZÓN**: Para entornos efímeros donde los datos no son críticos

---

### 2. **Tipos de carga de trabajo**

```yaml
# Para logs/métricas (escritura intensiva, lectura poco frecuente)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-logs
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "2"
  dataLocality: "best-effort"  # Prioriza escribir local (más rápido)
  replicaAutoBalance: "least-effort"
```

**RAZÓN**: Para Loki, Prometheus, logging → optimiza escritura

```yaml
# Para caché (puede perderse, lectura intensiva)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-cache
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"
  dataLocality: "strict-local"  # SOLO en nodo local (máxima velocidad)
```

**RAZÓN**: Para Redis, Memcached → velocidad sobre durabilidad

---

### 3. **Backup y recuperación**

```yaml
# Para volúmenes con backup automático
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-backed-up
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  recurringJobSelector: '[
    {"name":"backup-daily", "isGroup":true}
  ]'
```

**RAZÓN**: Aplica políticas de backup automáticas

---

### 4. **Separación por tipo de disco**

```yaml
# Solo SSD NVMe (máximo rendimiento)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-nvme
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  diskSelector: "nvme"
  nodeSelector: "storage-tier:nvme"
```

```yaml
# Solo HDD (gran capacidad, bajo costo)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-hdd
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  diskSelector: "hdd"
  nodeSelector: "storage-tier:capacity"
```

**RAZÓN**: Para archivos grandes poco frecuentes (backups, archivos)

---

## Ejemplo Real: Arquitectura Completa

```yaml
# ============================================================================
# ARQUITECTURA DE STORAGE CLASSES
# ============================================================================

# 1. TIER PLATINUM - Aplicaciones críticas
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-platinum
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain  # NO borra datos al eliminar PVC
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
  diskSelector: "ssd,nvme"
  dataLocality: "disabled"  # Distribuye en diferentes nodos (HA)
  replicaAutoBalance: "best-effort"
  fsType: "ext4"
# USO: PostgreSQL producción, Elasticsearch, bases de datos críticas

---
# 2. TIER GOLD - Aplicaciones importantes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-gold
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "1440"
  diskSelector: "ssd"
  dataLocality: "best-effort"
  fsType: "ext4"
# USO: MySQL staging, MongoDB, Redis persistente

---
# 3. TIER SILVER - Desarrollo y testing
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-silver
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # Por defecto
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  dataLocality: "best-effort"
  fsType: "ext4"
# USO: Default para la mayoría de workloads

---
# 4. TIER BRONZE - Efímero/Cache
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-bronze
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  dataLocality: "strict-local"  # Solo local (máxima velocidad)
  fsType: "ext4"
# USO: Caché, builds temporales, datos efímeros

---
# 5. STORAGE ESPECÍFICO - Archivos grandes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-bulk
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
parameters:
  numberOfReplicas: "2"
  diskSelector: "hdd"
  fsType: "ext4"
# USO: Backups, archivos multimedia, datos históricos
```

## 🎯 Tabla de decisión: ¿Qué StorageClass usar?

| Aplicación | StorageClass | Razón |
|------------|--------------|-------|
| **PostgreSQL Prod** | longhorn-platinum | Datos críticos, 3 réplicas, SSD |
| **Elasticsearch** | longhorn-gold | I/O intensivo, 2 réplicas suficientes |
| **Redis persistente** | longhorn-gold | Importante pero puede reconstruirse |
| **MySQL Dev** | longhorn-silver | No crítico, 2 réplicas OK |
| **Redis cache** | longhorn-bronze | Puede perderse, 1 réplica local |
| **Prometheus** | longhorn-silver | Datos de métricas, retención corta |
| **MinIO/Object Storage** | longhorn-bulk | Archivos grandes, HDD más económico |
| **Jenkins builds** | longhorn-bronze | Datos temporales, velocidad > durabilidad |
| **Backups** | longhorn-bulk | Gran capacidad, acceso infrecuente |

## Beneficios de esta estrategia

### **1. Performance adecuado**
- BBDD → baja latencia (SSD, local)
- Logs → alta escritura (optimizado)
- Cache → máxima velocidad (strict-local)

### **2. Gestión simplificada**
```bash
# Ver qué usa cada aplicación
kubectl get pvc --all-namespaces -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
STORAGECLASS:.spec.storageClassName,\
SIZE:.spec.resources.requests.storage
```

### **3. Troubleshooting fácil**
```bash
# "Esta BBDD va lenta"
# Revisas: ¿Está usando longhorn-platinum o longhorn-bronze?
# Si usa bronze → migra a platinum
```

## Parámetros importantes de Longhorn

```yaml
parameters:
  # Réplicas
  numberOfReplicas: "3"              # Cuántas copias (1-3)
  
  # Localidad de datos
  dataLocality: "disabled"           # Distribuido (HA)
  dataLocality: "best-effort"        # Prefiere local pero permite remoto
  dataLocality: "strict-local"       # SOLO local (más rápido, menos HA)
  
  # Selección de discos/nodos
  diskSelector: "ssd,nvme"           # Tags de discos a usar
  nodeSelector: "storage-tier:premium"  # Tags de nodos a usar
  
  # Backup
  recurringJobSelector: '[{"name":"backup-daily"}]'
  
  # Comportamiento
  staleReplicaTimeout: "30"          # Minutos antes de marcar réplica como obsoleta
  replicaAutoBalance: "best-effort"  # Rebalancea réplicas automáticamente
  
  # Sistema de archivos
  fsType: "ext4"                     # ext4 o xfs
  
  # Acceso
  migratable: "true"                 # Permite live migration
```

> Nota: Longhorn no sabe que disco es ssd o hhdd. Es necesario etiquetar los volumenes de los nodos por la interfaz de longhorn ó mediante el CRD de la configuración del nodo creado por longhorn. 

[⬅️ Anterior](../kubernetes-install/install.md) | [🏠 Volver al Inicio](../README.md) | [➡️ Siguiente](../postgres/postgres.md)


