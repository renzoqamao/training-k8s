# Instalación

Para la instalación del cluster de kubernetes levante tres máquinas virtuales linux ubuntu 24.04 con la siguiente configuración:

## Esquema de particionado recomendado

Con un disco de 200 GB puedes usar el siguiente esquema de particionado:

| Partición | Tamaño  | Formato | Punto de montaje |
|-----------|---------|---------|------------------|
| /boot     | 1 GiB   | ext4    | /boot            |
| swap      | 4 GiB   | swap    | —                |
| /         | 195 GiB | ext4    | /                |

> **Nota:** Todo el espacio restante se asigna a la partición raíz `/`, el cluster en total tiene 18vCPU y 24 GB de RAM

| Tipo de Nodo    |       IP      |  hostname   |
|-----------------|---------------|-------------|
| Nodo Maestro    | 192.168.1.100 |  masterk8s  |
| Nodo Trabajador | 192.168.1.101 |  worker01   |
| Nodo Trabajador | 192.168.1.102 |  worker02   |

## Proceso

Copiar toda la carpeta `kubernetes-install` a los nodos Master y workers.

```bash
scp -r .\kubernetes-install\ masterk8s@192.168.1.100:/home/masterk8s/ # scp -r .\kubernetes-install\ username@IP:/home/username/
ssh -p 22 masterk8s@192.168.1.100 # ssh username@IP
 ```

### Instalación de cluster Master

```bash
cd kubernetes-install
chmod +x *.sh
sudo ./k8s-master.sh
```

Una vez finalizado seguimos los pasos y copiamos los archivos a los workers

```bash
sudo cp /etc/kubernetes/admin.conf /home/masterk8s/admin.yaml
sudo chown masterk8s:masterk8s /home/masterk8s/admin.yaml
# ejemplo para un worker01 con IP 192.168.1.101
sudo scp /root/kubeadm_join_command.sh worker01@192.168.1.101:/tmp/
sudo scp /root/master_info.sh worker01@192.168.1.101:/tmp/
# ejemplo para un worker02 con IP 192.168.1.102
sudo scp /root/kubeadm_join_command.sh worker02@192.168.1.102:/tmp/
sudo scp /root/master_info.sh worker02@192.168.1.102:/tmp/
```

### Instalación de cluster Worker


```bash
 # scp -r .\kubernetes-install\ username@IP:/home/username/
 # worker 01
scp -r .\kubernetes-install\ worker01@192.168.1.101:/home/worker01/
ssh worker01@192.168.1.101 # ssh username@IP
 # worker 02
scp -r .\kubernetes-install\ worker02@192.168.1.102:/home/worker02/
ssh worker02@192.168.1.102 # ssh username@IP

 ```

```bash
sudo apt install iputils-ping -y
source /tmp/master_info.sh
cd kubernetes-install
chmod +x *.sh
sudo ./k8s-worker.sh
```

## Interactuar con el cluster de k8s

Se puede instalar kubectl(te permite comunicarte con la API de k8s) en [windows](https://kubernetes.io/es/docs/tasks/tools/included/install-kubectl-windows/) y [linux](https://kubernetes.io/es/docs/tasks/tools/included/install-kubectl-linux/).


Para conectarnos con el cluster descargamos el `admin.conf`(renombrar a `admin.yaml`) que se encuentra en `/etc/kubernetes` ó `/home/masterk8s`. Para cada terminal realizar la siguiente ejecución de la linea :

```powershell
scp masterk8s@192.168.1.100:/home/masterk8s/admin.yaml ./test/
$env:KUBECONFIG = "C:\Users\renzoqa\Documents\proyectos\rquispe\acs-enterprise-k8s\test\admin.yaml"
```

Para validar puede ejecutar el siguiente comando:

```powershell
kubectl config get-contexts
```

La salida seria algo similar a:

```powershell
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin
```

> Nota: Para efectos prácticos utilizaremos el administrador de kubernetes, pero en un entorno diferente de pruebas es necesario crear un ServiceAccount y User especificamente para ejecutar alfresco.

Ver los taints con kubectl en powershell

```powershell
kubectl get nodes -o json | ConvertFrom-Json | % { $_.items } | % {
    $name = $_.metadata.name
    $taints = $_.spec.taints
    if ($taints) {
        "$name tiene taints:"
        $taints | % { "  - Key: $($_.key), Effect: $($_.effect), Value: $($_.value)" }
    } else {
        "$name no tiene taints"
    }
}
```

Si sale :

```powershell
masterk8s tiene taints:
  - Key: node-role.kubernetes.io/control-plane, Effect: NoSchedule, Value: 
```

significa que 
Masterk8s tiene taints de no ejecutar pods.

worker01 no tiene Taints activos es decir:

* No hay restricciones (taints) impidiendo que se programen pods en ellos.

Quitar la restricción:

```powershell
kubectl taint nodes masterk8s node-role.kubernetes.io/control-plane:NoSchedule-
```

### Consideraciones

- Mantener las IP estaticas
- No solapar la interfaz de red del cluster con la red local `POD_NETWORK_CIDR`.
- En este caso se instaló y configuró containerd.
- La version de k8s es v1.31 `KUBERNETES_VERSION`.
- Es posible utilizar calico o cilium, en este caso se utilizó calico.
- En entornos productivos no se debería quitar la restricción de ejecución de pods en el nodo maestro.
- El DNS name es `k8scp` apuntando al master del cluster.
---

[🏠 Volver al Inicio](../README.md) | [➡️ Siguiente](../aprovisionamiento/aprovisionamiento.md)
