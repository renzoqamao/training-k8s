# Autoescalamiento Vertical de Pods

El VPA ajusta los `request` y `limits` de los pods y no el número de pods. El VPA no viene por defecto en kubernetes, es necesario realizar la instalación desde [github](https://github.com/kubernetes/autoscaler), es como una extensión del clúster.

> Nota: Cuando el pod actualiza sus recursos es reniciado.

## Instalación de VPA

1. Desde la terminal(linux) ejecutar lo siguientes:

```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler
git fetch --tags
git checkout vertical-pod-autoscaler-1.5.0
cd vertical-pod-autoscaler
./hack/vpa-up.sh
```

2. Probamos:

```bash
kubectl get deployments -n kube-system  | grep vpa
vpa-admission-controller   1/1     1            1           6m56s
vpa-recommender            1/1     1            1           7m45s
vpa-updater                1/1     1            1           7m58s
```

* Controlador de admisión:  establece las solicitudes de recursos actualizadas en nuevos pods a medida que se crean.
* Recomendador:  monitorea el uso actual y pasado y recomienda solicitudes de CPU y memoria.
* Actualizador:  verifica que los valores de las solicitudes estén actualizados y, si no es así, reinicia el pod finalizándolo primero.


## Ejemplo de VPA

1. vamos a actualizar el backend con la siguiente configuración VPA

```yaml
apiVersion: autoscaling.k8s.io/v1            # Versión estable del CRD de VPA. :contentReference[oaicite:0]{index=0}
kind: VerticalPodAutoscaler                   # Tipo de recurso.
metadata:
  name: backend-vpa                           # Nombre del VPA.
  namespace: ns-backend                       # Namespace donde vive el Deployment objetivo y donde va a crearse el vpa.
spec:
  targetRef:                                  # A qué workload aplica el VPA (objeto “controlador”).
    apiVersion: apps/v1                       # Debe apuntar al recurso real (Deployment/StatefulSet/RS).
    kind: Deployment
    name: backend

  updatePolicy:                               # ¿Cuándo aplica cambios el VPA?
    updateMode: "Recreate"                        # Auto / Initial / Off / Recreate / InPlaceOrRecreate*. :contentReference[oaicite:1]{index=1}

  resourcePolicy:                             # Reglas por contenedor (límites, mínimos, etc.)
    containerPolicies:
      - containerName: demo-backend           # Nombre EXACTO del contenedor del pod (usa '*' para todos).
        # (opcional) Si quieres restringir a ciertos recursos:
        # controlledResources: ["cpu","memory"]  # Por defecto VPA gestiona cpu y memory. 
        minAllowed:                           # minimo permitido.
          #cpu: 50m
          memory: 256Mi
        maxAllowed:                           # Máximo permitido.
          #cpu: 500m                           
          memory: 512Mi
        controlledValues: "RequestsOnly" #"RequestsAndLimits" # VPA puede ajustar solo requests o requests+y limits. :contentReference[oaicite:2]{index=2}

```

2. Actualizamos request.memory=128Mi del deployment

```bash
kubectl set resources deployment/backend -n ns-backend --containers=demo-backend --requests=memory=128Mi
```

3. Si vemos los eventos del VPA veremos que se va a eliminar un pod.

```bash
kubectl -n ns-backend describe vpa backend-vpa
Name:         backend-vpa
Namespace:    ns-backend
Labels:       <none>
Annotations:  <none>
API Version:  autoscaling.k8s.io/v1
Kind:         VerticalPodAutoscaler
Metadata:
  Creation Timestamp:  2025-10-04T03:56:54Z
  Generation:          3
  Resource Version:    748680
  UID:                 1ff9b621-3d06-48e0-8b6b-5d5c20737e6f
Spec:
  Resource Policy:
    Container Policies:
      Container Name:     demo-backend
      Controlled Values:  RequestsOnly
      Max Allowed:
        Memory:  512Mi
      Min Allowed:
        Memory:  256Mi
  Target Ref:
    API Version:  apps/v1
    Kind:         Deployment
    Name:         backend
  Update Policy:
    Update Mode:  Recreate
Status:
  Conditions:
    Last Transition Time:  2025-10-04T04:14:48Z
    Status:                True
    Type:                  RecommendationProvided
  Recommendation:
    Container Recommendations:
      Container Name:  demo-backend
      Lower Bound:
        Cpu:     25m
        Memory:  256Mi
      Target:
        Cpu:     25m
        Memory:  297164212
      Uncapped Target:
        Cpu:     25m
        Memory:  297164212
      Upper Bound:
        Cpu:     5610m
        Memory:  512Mi
Events:
  Type    Reason      Age   From         Message
  ----    ------      ----  ----         -------
  Normal  EvictedPod  50s   vpa-updater  VPA Updater evicted Pod backend-7d986986d4-gh65g to apply resource recommendation.
```


> Nota: El VPA no modifica la definición del deployment, lo que hace es cambiar los recursos del Pod.

4. Ver la información del deployment y validar que no cambia nada.

```bash
kubectl describe deploy backend -n ns-backend
```

[⬅️ Anterior](../HPA/HPA.md) | [🏠 Volver al Inicio](../README.md)