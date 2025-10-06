# Autoescalamiento Horizontal de Pods

## Servidor de Metricas (Metrics server)

La función principal es proporcionar métricas de CPU y memoria en tiempo real  a través de una API para que los escaladores automáticos puedan consumirla y realizar sus tareas. Además proporciona una vista sencilla y en tiempo real de qué pods consumen qué recursos mediante el comando `kubectl top`.

El HPA escala la cantidad de pods de una aplicación según la demanda de recursos.

## Instalación

1. Podemos realizar la instalación mediante Helm

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

2. Cambios en la implementación para permitir certificados inseguros.

```bash
kubectl -n kube-system patch deployment/metrics-server --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

3. Uso de top para ver el uso

```bash
kubectl top nodes
NAME        CPU(cores)   CPU(%)      MEMORY(bytes)   MEMORY(%)   
masterk8s   906m         11%         2318Mi          19%
worker01    438m         5%          1891Mi          15%
```

4. Ver el uso de los pods en todos los namespaces

```bash
kubectl top pods -A 
NAMESPACE          NAME                                                CPU(cores)   MEMORY(bytes)   
calico-apiserver   calico-apiserver-59c55bcf9c-65j27                   104m         94Mi
calico-apiserver   calico-apiserver-59c55bcf9c-fbfhj                   7m           35Mi
calico-system      calico-kube-controllers-795dc5c656-lqtqb            3m           57Mi
calico-system      calico-node-c8gch                                   79m          209Mi
calico-system      calico-node-rnz4k                                   407m         144Mi
calico-system      calico-typha-5bcd86bd46-wp2mv                       84m          62Mi
calico-system      csi-node-driver-c9mtg                               1m           29Mi
calico-system      csi-node-driver-dnrvk                               1m           29Mi
ingress-nginx      ingress-nginx-controller-7f4ff5945d-9vqnl           5m           146Mi
kube-system        coredns-7c65d6cfc9-fls87                            8m           17Mi
kube-system        coredns-7c65d6cfc9-ml6mk                            9m           58Mi
kube-system        etcd-masterk8s                                      766m         119Mi
kube-system        kube-apiserver-masterk8s                            1167m        410Mi
kube-system        kube-controller-manager-masterk8s                   559m         73Mi
kube-system        kube-proxy-4lhcs                                    22m          73Mi
kube-system        kube-proxy-d9g8w                                    2m           69Mi
kube-system        kube-scheduler-masterk8s                            113m         19Mi
kube-system        metrics-server-bf688598-g5nm8                       8m           21Mi
longhorn-system    csi-attacher-699d7b6777-qsq2p                       5m           13Mi
longhorn-system    csi-provisioner-84bbd9588b-wrrlv                    8m           16Mi
longhorn-system    csi-resizer-7878697556-mzknl                        3m           12Mi
longhorn-system    csi-snapshotter-765dc584c4-mmp7w                    13m          12Mi
longhorn-system    engine-image-ei-26bab25d-zm8qp                      71m          5Mi
longhorn-system    instance-manager-24a49abbdd164c20c7f62c769e361fe2   196m         62Mi
longhorn-system    instance-manager-962685e2417307f6a7113a7307bbe73d   94m          164Mi
longhorn-system    longhorn-csi-plugin-67thp                           60m          43Mi
longhorn-system    longhorn-csi-plugin-ssgh6                           4m           51Mi
longhorn-system    longhorn-driver-deployer-797d8894b9-8dfqm           2m           9Mi
longhorn-system    longhorn-manager-9ptt9                              232m         53Mi
longhorn-system    longhorn-manager-wln6p                              43m          121Mi
longhorn-system    longhorn-ui-84699c5cf5-9wnhn                        0m           9Mi
longhorn-system    longhorn-ui-84699c5cf5-bwzkz                        0m           2Mi
ns-postgresql      dev-sf-psql-0                                       12m          43Mi
tigera-operator    tigera-operator-6847585ccf-2rwnz                    158m         37Mi
```

5. Ver el uso de los contenedores en todos los namespaces

```bash
kubectl top pods -A --containers
NAMESPACE          POD                                                 NAME                           CPU(cores)   MEMORY(bytes)   
calico-apiserver   calico-apiserver-59c55bcf9c-65j27                   calico-apiserver               73m          94Mi
calico-apiserver   calico-apiserver-59c55bcf9c-fbfhj                   calico-apiserver               8m           35Mi
calico-system      calico-kube-controllers-795dc5c656-lqtqb            calico-kube-controllers        1m           57Mi
calico-system      calico-node-c8gch                                   calico-node                    61m          208Mi
calico-system      calico-node-rnz4k                                   calico-node                    245m         145Mi
calico-system      calico-typha-5bcd86bd46-wp2mv                       calico-typha                   99m          62Mi
calico-system      csi-node-driver-c9mtg                               calico-csi                     0m           12Mi
calico-system      csi-node-driver-c9mtg                               csi-node-driver-registrar      1m           16Mi
calico-system      csi-node-driver-dnrvk                               calico-csi                     0m           12Mi
calico-system      csi-node-driver-dnrvk                               csi-node-driver-registrar      1m           16Mi
ingress-nginx      ingress-nginx-controller-7f4ff5945d-9vqnl           controller                     5m           146Mi
kube-system        coredns-7c65d6cfc9-fls87                            coredns                        9m           17Mi
kube-system        coredns-7c65d6cfc9-ml6mk                            coredns                        11m          58Mi
kube-system        etcd-masterk8s                                      etcd                           662m         120Mi
kube-system        kube-apiserver-masterk8s                            kube-apiserver                 1044m        417Mi
kube-system        kube-controller-manager-masterk8s                   kube-controller-manager        516m         73Mi
kube-system        kube-proxy-4lhcs                                    kube-proxy                     42m          73Mi
kube-system        kube-proxy-d9g8w                                    kube-proxy                     1m           69Mi
kube-system        kube-scheduler-masterk8s                            kube-scheduler                 142m         19Mi
kube-system        metrics-server-bf688598-g5nm8                       metrics-server                 15m          21Mi
longhorn-system    csi-attacher-699d7b6777-qsq2p                       csi-attacher                   5m           13Mi
longhorn-system    csi-provisioner-84bbd9588b-wrrlv                    csi-provisioner                11m          16Mi
longhorn-system    csi-resizer-7878697556-mzknl                        csi-resizer                    3m           12Mi
longhorn-system    csi-snapshotter-765dc584c4-mmp7w                    csi-snapshotter                12m          11Mi
longhorn-system    engine-image-ei-26bab25d-mlfcd                      engine-image-ei-26bab25d       226m         6Mi
longhorn-system    engine-image-ei-26bab25d-zm8qp                      engine-image-ei-26bab25d       59m          5Mi
longhorn-system    instance-manager-24a49abbdd164c20c7f62c769e361fe2   instance-manager               179m         62Mi
longhorn-system    instance-manager-962685e2417307f6a7113a7307bbe73d   instance-manager               77m          164Mi
longhorn-system    longhorn-csi-plugin-67thp                           longhorn-csi-plugin            24m          11Mi
longhorn-system    longhorn-csi-plugin-67thp                           longhorn-liveness-probe        25m          27Mi
longhorn-system    longhorn-csi-plugin-67thp                           node-driver-registrar          1m           4Mi
longhorn-system    longhorn-csi-plugin-ssgh6                           longhorn-csi-plugin            4m           18Mi
longhorn-system    longhorn-csi-plugin-ssgh6                           longhorn-liveness-probe        4m           27Mi
longhorn-system    longhorn-csi-plugin-ssgh6                           node-driver-registrar          1m           5Mi
longhorn-system    longhorn-driver-deployer-797d8894b9-8dfqm           longhorn-driver-deployer       0m           9Mi
longhorn-system    longhorn-manager-9ptt9                              longhorn-manager               221m         53Mi
longhorn-system    longhorn-manager-9ptt9                              pre-pull-share-manager-image   0m           0Mi
longhorn-system    longhorn-manager-wln6p                              longhorn-manager               49m          120Mi
longhorn-system    longhorn-manager-wln6p                              pre-pull-share-manager-image   0m           0Mi
longhorn-system    longhorn-ui-84699c5cf5-9wnhn                        longhorn-ui                    0m           9Mi
longhorn-system    longhorn-ui-84699c5cf5-bwzkz                        longhorn-ui                    0m           2Mi
ns-postgresql      dev-sf-psql-0                                       postgres                       13m          43Mi
tigera-operator    tigera-operator-6847585ccf-2rwnz                    tigera-operator                135m         36Mi
```

## Creación de un HPA

1. Ese manifiesto crea un **HorizontalPodAutoscaler (HPA)** que **escala automáticamente** tu Deployment `backend` según **CPU**.

### Qué hace exactamente

* **Objetivo**: mantener la **utilización promedio de CPU = 50%** por pod.
* **Rango de réplicas**: entre **1 y 5** (`minReplicas` y `maxReplicas`).
* **Ámbito**: `namespace: ns-backend`.

En la práctica:

* Si la media de CPU de los pods (respecto a sus **requests**) **supera 50%**, el HPA **aumenta** réplicas.
* Si la media **baja de 50%**, **reduce** réplicas (con estabilización para evitar saltos).

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
    name: backend-hpa
    namespace: ns-backend
spec:
    scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: backend
    minReplicas: 1
    maxReplicas: 5
    metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

2. Para probar el HPA utilizamos los siguientes comandos:

- Para monitorear los pods en tiempo real: `kubectl get pods -w -n ns-backend`

- Para modificar manualmente la cantidad de replicas del deployment: `kubectl scale --replicas=4 deployment/backend -n ns-backend`

3. El monitoreo de pods mostrará algo como:

```bash
kubectl get pods -w -n ns-backend
NAME                       READY   STATUS        RESTARTS   AGE
backend-5bc45bbbb6-cb6v2   0/1     Terminating   0          56s
backend-5bc45bbbb6-m5wx8   0/1     Error         0          56s
backend-5bc45bbbb6-tg5h9   0/1     Terminating   0          56s
backend-5bc45bbbb6-z7sh2   1/1     Running       0          43m
backend-5bc45bbbb6-m5wx8   0/1     Error         0          57s
backend-5bc45bbbb6-m5wx8   0/1     Error         0          58s
backend-5bc45bbbb6-tg5h9   0/1     Error         0          63s
backend-5bc45bbbb6-tg5h9   0/1     Error         0          65s
backend-5bc45bbbb6-tg5h9   0/1     Error         0          66s
backend-5bc45bbbb6-cb6v2   0/1     Error         0          75s
backend-5bc45bbbb6-cb6v2   0/1     Error         0          77s
backend-5bc45bbbb6-cb6v2   0/1     Error         0          78s
```

[⬅️ Anterior](../backend/backend.md) | [🏠 Volver al Inicio](../README.md)