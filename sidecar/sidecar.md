# Sidecar

Un `sidecar` es un contenedor que corre junto con el contenedor principal en el mismo pod para darle más funcionalidades( publicación de métricas, logs, proxys, recarga de configs, secrets, etc). Comparte red(localhost) y volúmenes con el contenedor principal, pero tiene recursos/probes propios. Si el sidecar cae, afecta al Pod, es posible que lo saqué del balanceo. Sucede los siguientes casos:

* El Pod no muere: en un Deployment los contenedores (incluido el sidecar) tienen `restartPolicy: Always`. Si el sidecar se cae (sale con código ≠ 0 o lo mata el OOM), kubelet lo reinicia. El Pod sigue vivo en `Running` pero con el sidecar en `CrashLoopBackOff` mientras reintenta.

* Ready vs NoReady: la condición `ContainersReady` del Pod es verdadera solo si todos los contenedores están `ready`.
    * Si el sidecar no está `ready` (porque se cayó o falla su readinessProbe), el Pod pasa a `NotReady` y sale de los Endpoints del Service (deja de recibir tráfico).
    * Si al sidecar no le pones readiness (y no es crítico), su caída lo deja “no running” y el Pod igualmente no estará `ContainersReady`. Por eso, en la práctica, solo pongas probes a sidecars críticos para servir tráfico.
* Cuándo sí “se cae” el Pod: si todos los contenedores terminan y no hay reinicio posible, el Pod queda `Failed/Succeeded`. Con Deployments, el ReplicaSet creará otro Pod, pero no es lo habitual por un sidecar que se reinicia.



## Implementación de un sidecar para realizar un diagnostico rápido de red

1. Utilizamos la imagen de netshhot. Nos va a permitir ingresar al pod y hacer `curl`, `dig`, ``nc`.

```yaml
- name: netshoot
  image: nicolaka/netshoot:latest
  command: ["bash","-lc","sleep infinity"]
  resources:
    requests: { cpu: "10m", memory: "32Mi" }
    limits:   { cpu: "100m", memory: "128Mi" }

```

2. Ingresamos a uno de los sidecar del deployment para realizar las pruebas correspondientes:

```bash
kubectl -n ns-backend exec -it deploy/backend -c netshoot -- bash
backend-778fc66c6b-5np9v:~# nc -zv postgresql.ns-backend.svc.cluster.local 5432
nc: getaddrinfo for host "postgresql.ns-backend.svc.cluster.local" port 5432: Name does not resolve
backend-778fc66c6b-5np9v:~# nc -zv dev-psql-hl-svc.ns-postgresql.svc.cluster.local 5432
Connection to dev-psql-hl-svc.ns-postgresql.svc.cluster.local (100.200.5.24) 5432 port [tcp/postgresql] succeeded!
```

[⬅️ Anterior](../initContainers/initContainers.md) | [🏠 Volver al Inicio](../README.md) 