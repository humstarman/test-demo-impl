# Kubernetes ngixn ingress
Manifest to deploy nginx ingress on Kubernetes.  

## Deploying namespace & rbac
```bash
kubectl create -f namespace.yaml
kubectl create -f rbac.yaml
```

## Deploying default http backend
```bash
kubectl create -f default-backend.yaml
```

## Deploying config maps 
```bash
kubectl create -f configmap.yaml
kubectl create -f tcp-services-configmap.yaml
kubectl create -f udp-services-configmap.yaml
```

## Deploying the core service 
```bash
kubectl create -f service.yaml
kubectl create -f with-rbac.yaml
```
