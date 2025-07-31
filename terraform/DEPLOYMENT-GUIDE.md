# Military Unit Voting System - EKS Deployment Guide

This guide covers both **Production** and **Free Tier** deployment options for the Military Unit Voting System on Amazon EKS.

## Configuration Options

### 1. **Production Deployment** (`terraform-prod.tfvars`)
- **Purpose**: Full-scale military operations
- **Cost**: ~$200-400/month
- **Features**: High availability, auto-scaling, monitoring
- **Nodes**: 3-10 t3.medium/large instances
- **Use Case**: Actual military unit voting operations

### 2. **Free Tier Deployment** (`terraform-freetier.tfvars`)
- **Purpose**: Demonstration and testing
- **Cost**: ~$73-80/month (EKS control plane only)
- **Features**: Single node, minimal resources
- **Nodes**: 1 t3.micro instance (Free Tier eligible)
- **Use Case**: Military demonstrations, proof of concept

## Quick Start

### Choose Your Deployment Type

#### **Option A: Production Deployment**
```bash
cd terraform/
cp terraform-prod.tfvars terraform.tfvars
```

#### **Option B: Free Tier Deployment**
```bash
cd terraform/
cp terraform-freetier.tfvars terraform.tfvars
```

#### **Option C: Custom Configuration**
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to customize settings
```

### Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply
```

### Configure kubectl

```bash
# Production
aws eks --region us-west-2 update-kubeconfig --name military-voting-system-prod

# Free Tier
aws eks --region us-east-1 update-kubeconfig --name military-voting-freetier
```

## Configuration Comparison

| Feature | Production | Free Tier |
|---------|------------|-----------|
| **Region** | us-west-2 | us-east-1 |
| **Cluster Name** | military-voting-system-prod | military-voting-freetier |
| **Node Count** | 3-10 nodes | 1 node |
| **Instance Type** | t3.medium, t3.large | t3.micro |
| **Storage** | 50GB per node | 8GB total |
| **Monitoring** | CloudWatch enabled | Disabled (cost savings) |
| **Auto-scaling** | Yes (2-10 nodes) | No (fixed 1 node) |
| **Monthly Cost** | $200-400 | $73-80 |
| **Use Case** | Production operations | Demo/testing |

## Architecture Differences

### **Production Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    Production Setup                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                VPC (10.0.0.0/16)                       │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │   Public AZ-1   │    │   Public AZ-2   │             │ │
│  │  │  Load Balancers │    │  Load Balancers │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │  Private AZ-1   │    │  Private AZ-2   │             │ │
│  │  │                 │    │                 │             │ │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │             │ │
│  │  │  │    EKS    │  │    │  │    EKS    │  │             │ │
│  │  │  │   Nodes   │  │    │  │   Nodes   │  │             │ │
│  │  │  │ t3.medium │  │    │  │ t3.large  │  │             │ │
│  │  │  └───────────┘  │    │  └───────────┘  │             │ │
│  │  │                 │    │                 │             │ │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │             │ │
│  │  │  │    EKS    │  │    │  │    EKS    │  │             │ │
│  │  │  │   Nodes   │  │    │  │   Nodes   │  │             │ │
│  │  │  │ t3.medium │  │    │  │ t3.medium │  │             │ │
│  │  │  └───────────┘  │    │  └───────────┘  │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### **Free Tier Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    Free Tier Setup                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                VPC (10.0.0.0/16)                       │ │
│  │                                                         │ │
│  │  ┌─────────────────┐                                    │ │
│  │  │   Public AZ-1   │                                    │ │
│  │  │  Load Balancer  │                                    │ │
│  │  └─────────────────┘                                    │ │
│  │                                                         │ │
│  │  ┌─────────────────┐                                    │ │
│  │  │  Private AZ-1   │                                    │ │
│  │  │                 │                                    │ │
│  │  │  ┌───────────┐  │    Single Node                     │ │
│  │  │  │    EKS    │  │    All Services                    │ │
│  │  │  │   Node    │  │    Resource Limited                │ │
│  │  │  │ t3.micro  │  │    1 vCPU, 1GB RAM                │ │
│  │  │  └───────────┘  │                                    │ │
│  │  └─────────────────┘                                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Application Deployment

### **Production Deployment**
```bash
# Use standard Kubernetes manifests
kubectl apply -k k8s/

# Services will have multiple replicas and full resources
kubectl get pods -n military-voting
```

### **Free Tier Deployment**
```bash
# Use resource-optimized manifests
kubectl apply -k k8s-freetier/

# Services will have single replicas and minimal resources
kubectl get pods -n military-voting
```

## Cost Management

### **Production Costs**
- **EKS Control Plane**: $73/month
- **EC2 Instances**: $100-300/month (3-10 nodes)
- **EBS Storage**: $15-50/month
- **Load Balancers**: $20-40/month
- **Data Transfer**: $10-30/month
- **Total**: ~$200-400/month

### **Free Tier Costs**
- **EKS Control Plane**: $73/month (not free)
- **EC2 t3.micro**: FREE (750 hours/month)
- **EBS Storage**: FREE (under 30GB limit)
- **Load Balancers**: $18/month (minimal)
- **Data Transfer**: FREE (under 1GB/month)
- **Total**: ~$73-80/month

## Environment-Specific Features

### **Production Features**
- ✅ Multi-AZ deployment
- ✅ Auto-scaling (2-10 nodes)
- ✅ CloudWatch monitoring
- ✅ Multiple instance types
- ✅ High availability
- ✅ Production-grade storage
- ✅ Comprehensive logging

### **Free Tier Features**
- ✅ Single-AZ deployment
- ❌ No auto-scaling (fixed 1 node)
- ❌ Monitoring disabled
- ✅ Free Tier instance (t3.micro)
- ❌ Limited availability
- ✅ Minimal storage
- ✅ Basic logging

## Important Considerations

### **Production Deployment**
- **Security**: Update `cluster_endpoint_public_access_cidrs` with military network ranges
- **Compliance**: Ensure DoD compliance requirements are met
- **Backup**: Implement backup strategies for persistent data
- **Monitoring**: Set up alerting for operational issues

### **Free Tier Deployment**
- **Cost Monitoring**: Set up billing alerts at $10, $50, $75
- **Resource Limits**: Single node may require sequential service deployment
- **Demonstration Only**: Not suitable for actual military operations
- **Cleanup**: Remember to destroy resources when not in use

## Cleanup

### **Stop Charges**
```bash
# Scale down applications
kubectl scale deployment --all --replicas=0 -n military-voting

# Destroy infrastructure
terraform destroy
```

### **Partial Cleanup (Keep Infrastructure)**
```bash
# Just scale down applications to save on compute
kubectl scale deployment --all --replicas=0 -n military-voting
```

## Next Steps

1. **Choose your deployment type** based on use case
2. **Configure variables** using the appropriate `.tfvars` file
3. **Deploy infrastructure** with Terraform
4. **Build and push** container images to ECR
5. **Deploy application** using appropriate Kubernetes manifests
6. **Test the system** with military personnel
7. **Monitor costs** and performance

Both configurations are ready for deployment and optimized for their respective use cases!
