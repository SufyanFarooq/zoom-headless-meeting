# Kubernetes Setup Guide

## Why Kubernetes?

Kubernetes provides:
- ✅ **Auto-scaling**: Automatically add/remove bot servers based on load
- ✅ **Load Balancing**: Built-in service discovery and load balancing
- ✅ **Health Checks**: Auto-restart failed containers
- ✅ **Rolling Updates**: Zero-downtime deployments
- ✅ **Resource Management**: Better CPU/memory allocation
- ✅ **Multi-Node**: Run pods across multiple servers automatically

## Architecture

```
┌─────────────────────────────────────┐
│         Kubernetes Cluster           │
│                                     │
│  ┌──────────────┐  ┌──────────────┐│
│  │ API Server   │  │  PostgreSQL  ││
│  │  (1 replica)  │  │  (1 replica) ││
│  └──────────────┘  └──────────────┘│
│                                     │
│  ┌──────────────┐  ┌──────────────┐│
│  │ Bot Server 1  │  │ Bot Server 2 ││
│  │  (auto-scale) │  │  (auto-scale)││
│  └──────────────┘  └──────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │   Bot Pods (auto-scaled)       ││
│  │   zoom-bot-1, zoom-bot-2, ...  ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

## Prerequisites

1. **Kubernetes Cluster** (minikube, k3s, EKS, GKE, etc.)
2. **kubectl** configured
3. **Docker images** built and pushed to registry
4. **Persistent Volume** for database

## Quick Start

### Step 1: Build and Push Docker Images

```bash
# Build images
docker build -t zoom-api:latest -f Dockerfile.api .
docker build -t zoom-bot-server:latest -f Dockerfile.bot-server .
docker build -t zoom-bot:latest -f Dockerfile .

# Tag for registry (replace with your registry)
docker tag zoom-api:latest your-registry/zoom-api:latest
docker tag zoom-bot-server:latest your-registry/zoom-bot-server:latest
docker tag zoom-bot:latest your-registry/zoom-bot:latest

# Push to registry
docker push your-registry/zoom-api:latest
docker push your-registry/zoom-bot-server:latest
docker push your-registry/zoom-bot:latest
```

### Step 2: Create ConfigMap and Secrets

```bash
# Create namespace
kubectl create namespace zoom-bots

# Create secrets
kubectl create secret generic zoom-secrets \
  --from-literal=db-password=your_password \
  --from-literal=zoom-account-id=your_account_id \
  --from-literal=zoom-client-id=your_client_id \
  --from-literal=zoom-client-secret=your_secret \
  -n zoom-bots

# Create configmap
kubectl apply -f k8s/zoom-bot-configmap.yaml
```

### Step 3: Deploy Services

```bash
# Deploy PostgreSQL
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: zoom-bots
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: zoom_bots
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: zoom-secrets
              key: db-password
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: zoom-bots
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Deploy API Server
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: zoom-bots
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: api
        image: your-registry/zoom-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: zoom_bots
        - name: DB_USER
          value: postgres
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: zoom-secrets
              key: db-password
        - name: ZOOM_ACCOUNT_ID
          valueFrom:
            secretKeyRef:
              name: zoom-secrets
              key: zoom-account-id
        - name: ZOOM_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: zoom-secrets
              key: zoom-client-id
        - name: ZOOM_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: zoom-secrets
              key: zoom-client-secret
---
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: zoom-bots
spec:
  selector:
    app: api-server
  ports:
  - port: 3000
    targetPort: 3000
  type: LoadBalancer
EOF

# Deploy Bot Servers (with auto-scaling)
kubectl apply -f k8s/zoom-bot-deployment.yaml
kubectl apply -f k8s/zoom-bot-hpa.yaml  # Horizontal Pod Autoscaler
```

### Step 4: Initialize Database

```bash
# Wait for postgres to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n zoom-bots --timeout=300s

# Copy schema to postgres pod
kubectl cp database/schema.sql zoom-bots/postgres-0:/tmp/schema.sql

# Run schema
kubectl exec -it postgres-0 -n zoom-bots -- psql -U postgres -d zoom_bots -f /tmp/schema.sql
```

### Step 5: Register Bot Servers

Bot servers are automatically registered via service discovery. The API server discovers bot servers via Kubernetes services.

## Auto-Scaling Configuration

### Horizontal Pod Autoscaler (HPA)

```yaml
# k8s/zoom-bot-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bot-server-hpa
  namespace: zoom-bots
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bot-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

This will:
- Start with 2 bot server pods
- Scale up to 10 pods when CPU > 70% or Memory > 80%
- Scale down when load decreases

## Service Discovery

Bot servers are automatically discovered via Kubernetes DNS:

```javascript
// In api/services/botService.js
// Bot server service name: bot-server.zoom-bots.svc.cluster.local
const botServerUrl = `http://bot-server.zoom-bots.svc.cluster.local:3001`;
```

## Advantages Over Docker Compose

| Feature | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Scaling** | Manual | Automatic (HPA) |
| **Load Balancing** | Manual (priority) | Built-in (Service) |
| **Health Checks** | Basic | Advanced (Liveness/Readiness) |
| **Rolling Updates** | Manual | Automatic |
| **Multi-Node** | Manual setup | Automatic |
| **Resource Limits** | Static | Dynamic |
| **Self-Healing** | Limited | Full |

## Monitoring

```bash
# Check pod status
kubectl get pods -n zoom-bots

# Check services
kubectl get svc -n zoom-bots

# Check HPA
kubectl get hpa -n zoom-bots

# View logs
kubectl logs -f deployment/api-server -n zoom-bots
kubectl logs -f deployment/bot-server -n zoom-bots

# Scale manually
kubectl scale deployment bot-server --replicas=5 -n zoom-bots
```

## Production Recommendations

1. **Use Ingress** for external access:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: zoom-bots-ingress
     namespace: zoom-bots
   spec:
     rules:
     - host: api.yourdomain.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: api-server
               port:
                 number: 3000
   ```

2. **Use Persistent Volumes** for database
3. **Set Resource Requests/Limits**:
   ```yaml
   resources:
     requests:
       cpu: "100m"
       memory: "128Mi"
     limits:
       cpu: "500m"
       memory: "512Mi"
   ```

4. **Use ConfigMaps** for non-sensitive config
5. **Use Secrets** for sensitive data (already done)

## Migration from Docker Compose

1. Build and push images to registry
2. Create Kubernetes manifests (use provided examples)
3. Deploy to cluster
4. Update API server to use Kubernetes service discovery
5. Test and verify
6. Switch DNS to Kubernetes ingress

## Summary

Kubernetes provides:
- ✅ Better scalability (auto-scaling)
- ✅ Better reliability (auto-restart)
- ✅ Better resource management
- ✅ Multi-node support out of the box
- ✅ Production-ready features

For production deployments, Kubernetes is recommended over Docker Compose.

