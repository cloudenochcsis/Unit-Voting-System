# AWS Free Tier EKS Deployment Guide

## Important Cost Considerations

### EKS Costs (NOT Free Tier Eligible)
- **EKS Control Plane**: $0.10/hour = ~$73/month
- **This is the main cost** - EKS control plane is never free

### Free Tier Resources Used
- **EC2 t3.micro**: 750 hours/month (1 instance = FREE)
- **EBS Storage**: 30GB/month (we use 8GB = FREE)
- **VPC/Networking**: Basic networking is free
- **ECR**: 500MB storage/month (FREE for small images)

### Expected Monthly Cost: ~$73-80
- EKS Control Plane: $73
- Data transfer: $2-5 (minimal with single node)
- **Total: ~$73-80/month**

## Free Tier Optimized Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Free Tier Setup                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                VPC (10.0.0.0/16)                       │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │   Public AZ-1   │    │   Public AZ-2   │             │ │
│  │  │  (10.0.0.0/24)  │    │  (10.0.1.0/24)  │             │ │
│  │  │                 │    │                 │             │ │
│  │  │  ┌───────────┐  │    │                 │             │ │
│  │  │  │    NAT    │  │    │   (No NAT to    │             │ │
│  │  │  │  Gateway  │  │    │   save costs)   │             │ │
│  │  │  └───────────┘  │    │                 │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  │                                                         │ │
│  │  ┌─────────────────┐                                    │ │
│  │  │  Private AZ-1   │                                    │ │
│  │  │ (10.0.10.0/24)  │                                    │ │
│  │  │                 │                                    │ │
│  │  │  ┌───────────┐  │    Single t3.micro node           │ │
│  │  │  │    EKS    │  │    (FREE TIER ELIGIBLE)           │ │
│  │  │  │   Node    │  │    750 hours/month                │ │
│  │  │  │ t3.micro  │  │                                    │ │
│  │  │  └───────────┘  │                                    │ │
│  │  └─────────────────┘                                    │ │
│  │                                                         │ │
│  │              ┌─────────────────┐                        │ │
│  │              │   EKS Cluster   │                        │ │
│  │              │  Control Plane  │  $0.10/hour            │ │
│  │              │   (~$73/month)  │  (NOT FREE)            │ │
│  │              └─────────────────┘                        │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Free Tier Deployment Steps

### Step 1: Use Free Tier Configuration

```bash
cd terraform/

# Use the Free Tier optimized configuration
cp terraform-freetier.tfvars terraform.tfvars

# Review the settings
cat terraform.tfvars
```

### Step 2: Deploy with Cost Monitoring

```bash
# Initialize Terraform
terraform init

# Review the plan (check estimated costs)
terraform plan

# Deploy (monitor AWS billing dashboard)
terraform apply
```

### Step 3: Configure kubectl

```bash
# Configure kubectl
aws eks --region us-east-1 update-kubeconfig --name military-voting-freetier

# Verify single node
kubectl get nodes
```

## Application Deployment Strategy

### Single Node Considerations

With only 1 t3.micro node (1 vCPU, 1GB RAM), you need to optimize:

1. **Resource Limits**: Set strict CPU/memory limits
2. **Replica Counts**: Use 1 replica per service initially
3. **Resource Requests**: Minimal requests to fit everything

### Updated Kubernetes Manifests

Create `k8s-freetier/` directory with optimized manifests:

```yaml
# Example: vote-deployment-freetier.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vote
  namespace: military-voting
spec:
  replicas: 1  # Single replica for Free Tier
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
    spec:
      containers:
      - name: vote
        image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/military-voting-freetier/vote-service:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"    # Minimal memory request
            cpu: "50m"        # 0.05 CPU cores
          limits:
            memory: "128Mi"   # Low memory limit
            cpu: "100m"       # 0.1 CPU cores
        env:
        - name: REDIS_HOST
          value: redis
```

## Cost Optimization Tips

### 1. Monitor Usage Closely

```bash
# Check AWS billing dashboard daily
# Set up billing alerts for $10, $50, $75

# Monitor Free Tier usage
aws ce get-usage-and-costs --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

### 2. Minimize Data Transfer

- Use `us-east-1` region (often cheapest)
- Avoid unnecessary external API calls
- Use internal service communication

### 3. Resource Efficiency

```bash
# Monitor node resource usage
kubectl top nodes
kubectl top pods -n military-voting

# Scale down when not in use
kubectl scale deployment vote --replicas=0 -n military-voting
```

### 4. Development Workflow

```bash
# Start services only when needed
kubectl scale deployment vote --replicas=1 -n military-voting
kubectl scale deployment result --replicas=1 -n military-voting
kubectl scale deployment worker --replicas=1 -n military-voting

# Stop when done testing
kubectl scale deployment vote --replicas=0 -n military-voting
kubectl scale deployment result --replicas=0 -n military-voting
kubectl scale deployment worker --replicas=0 -n military-voting
```

## Resource Allocation Strategy

### Single Node Resource Distribution

With t3.micro (1 vCPU, 1GB RAM):

```
Available Resources (after system pods):
- CPU: ~0.7 cores
- Memory: ~700MB

Allocation:
- Vote Service:   CPU: 100m, Memory: 128Mi
- Result Service: CPU: 100m, Memory: 128Mi  
- Worker Service: CPU: 100m, Memory: 128Mi
- Redis:          CPU: 100m, Memory: 128Mi
- PostgreSQL:     CPU: 200m, Memory: 256Mi
- System Reserve: CPU: 200m, Memory: 132Mi
```

## Limitations & Alternatives

### Free Tier Limitations

1. **Single Node**: No high availability
2. **Limited Resources**: May need to run services one at a time
3. **No Auto-scaling**: Fixed capacity
4. **Development Only**: Not suitable for production

### Alternative Approaches

#### Option 1: Local Development
```bash
# Use docker-compose for local development
docker-compose up -d

# Deploy to EKS only for testing/demo
```

#### Option 2: Fargate (More Expensive)
- No EC2 management
- Pay per pod execution time
- May exceed Free Tier quickly

#### Option 3: Minikube
```bash
# Free local Kubernetes
minikube start --memory=2048 --cpus=2
kubectl apply -k k8s/
```

## Cost-Aware Cleanup

### Daily Cleanup (Save Money)
```bash
# Scale down applications when not in use
kubectl scale deployment --all --replicas=0 -n military-voting
```

### Complete Cleanup
```bash
# Delete everything to stop charges
kubectl delete -k k8s/
terraform destroy  # This stops the $73/month EKS charge
```

## Monitoring & Alerts

### Set Up Billing Alerts

1. Go to AWS Billing Dashboard
2. Create alerts for:
   - $10 (early warning)
   - $50 (approaching limit)
   - $75 (near monthly EKS cost)

### Daily Cost Monitoring

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics BlendedCost
```

## Success Criteria

You'll know the Free Tier setup is working when:

- ✅ Single t3.micro node running
- ✅ All 5 services deployed (may need sequential deployment)
- ✅ Monthly AWS bill stays ~$73-80
- ✅ Free Tier EC2 hours not exceeded (750/month)
- ✅ Application accessible via LoadBalancer

**Remember**: The main cost is the EKS control plane ($73/month). Everything else can stay within Free Tier limits with careful resource management.
