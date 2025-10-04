# Init Containers

Contenedores que se ejecutan antes de los contenedores principales en el Pod. Corren hasta completarse, y si todo termina Ok (según su exit code). Sirven para preparar al Pod para ejecutar los contenedores principales: descargan dependencias, preparan archivos/permisos, etc.

Se va a utilizar el deployment de backend, a la cual esperamos a que la conexión a la base de datos este lista.

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ["sh","-c"]
      args:
        - >
          set -eu;
          echo "Esperando DB $DB_HOST:$DB_PORT...";
          until nc -z "$DB_HOST" "$DB_PORT"; do
            echo "aún no disponible..."; sleep 2;
          done;
          echo "DB lista Ok";
      env:
        - name: DB_HOST
          value: "dev-psql-hl-svc.ns-postgresql.svc.cluster.local"
        - name: DB_PORT
          value: "5432"
```

1. Vemos el pod que se esta creando

```bash
kubectl get pods -n ns-backend
```

2. Tomamos el nombre de uno para obtener los logs del initContainer del pod.

```bash
kubectl logs backend-8f5cb99df-99mgf -c wait-for-db -n ns-backend

Esperando DB dev-psql-hl-svc.ns-postgresql.svc.cluster.local:5432...
DB lista Ok
```

[⬅️ Anterior](../VPA/VPA.md) | [🏠 Volver al Inicio](../README.md)