# EKS Cluster Provisioning for Military Unit Voting System

This Terraform configuration provisions a production-ready Amazon EKS cluster specifically designed for the Military Unit Voting System application.

## 🏗️ Infrastructure Overview

### What This Creates

- **EKS Cluster**: Kubernetes 1.31 cluster with managed control plane
- **VPC & Networking**: Custom VPC with public/private subnets across 2 AZs
- **Node Groups**: Managed EC2 instances for running workloads
- **ECR Repositories**: Container registries for vote, result, and worker services
- **IAM Roles**: Proper permissions for cluster and node operations
- **Security Groups**: Network security for cluster communication
- **EKS Add-ons**: Essential cluster components (EBS CSI, CoreDNS, etc.)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Region                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │   Public AZ-1   │    │   Public AZ-2   │             │ │
│  │  │  (10.0.0.0/24)  │    │  (10.0.1.0/24)  │             │ │
│  │  │                 │    │                 │             │ │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │             │ │
│  │  │  │    NAT    │  │    │  │    NAT    │  │             │ │
│  │  │  │  Gateway  │  │    │  │  Gateway  │  │             │ │
│  │  │  └───────────┘  │    │  └───────────┘  │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │  Private AZ-1   │    │  Private AZ-2   │             │ │
│  │  │ (10.0.10.0/24)  │    │ (10.0.11.0/24)  │             │ │
│  │  │                 │    │                 │             │ │
│  │  │  ┌───────────┐  │    │  ┌───────────┐  │             │ │
│  │  │  │    EKS    │  │    │  │    EKS    │  │             │ │
│  │  │  │   Nodes   │  │    │  │   Nodes   │  │             │ │
│  │  │  └───────────┘  │    │  └───────────┘  │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  │                                                         │ │
│  │              ┌─────────────────┐                        │ │
│  │              │   EKS Cluster   │                        │ │
│  │              │  Control Plane  │                        │ │
│  │              └─────────────────┘                        │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **kubectl** installed for cluster management
4. **Docker** for building and pushing container images

### Step 1: Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables to match your requirements
vim terraform.tfvars
```

### Step 2: Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### Step 3: Configure kubectl

```bash
# Configure kubectl to connect to your new cluster
aws eks --region us-west-2 update-kubeconfig --name military-voting-system
```

### Step 4: Verify Cluster

```bash
# Check cluster status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

## 📦 Container Image Management

### Build and Push Images to ECR

```bash
# Get ECR login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build and push vote service
docker build -t military-voting-system/vote-service:latest vote-service/
docker tag military-voting-system/vote-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/vote-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/vote-service:latest

# Build and push result service
docker build -t military-voting-system/result-service:latest result-service/
docker tag military-voting-system/result-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/result-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/result-service:latest

# Build and push worker service
docker build -t military-voting-system/worker-service:latest worker-service/
docker tag military-voting-system/worker-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/worker-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/worker-service:latest
```

## 🎯 Deploy the Voting Application

### Update Kubernetes Manifests

Update your `k8s/` deployment files to use the ECR image URLs:

```yaml
# In vote-deployment.yaml, result-deployment.yaml, worker-deployment.yaml
spec:
  containers:
  - name: vote
    image: <account-id>.dkr.ecr.us-west-2.amazonaws.com/military-voting-system/vote-service:latest
    imagePullPolicy: Always
```

### Deploy to EKS

```bash
# Deploy the application
kubectl apply -k k8s/

# Check deployment status
kubectl get all -n military-voting

# Get LoadBalancer URLs
kubectl get services -n military-voting
```

## 🔧 Configuration Options

### Environment-Specific Configurations

#### Development Environment
```hcl
environment = "dev"
node_group_capacity_type = "SPOT"
node_group_instance_types = ["t3.small"]
node_group_desired_size = 1
node_group_max_size = 2
```

#### Production Environment
```hcl
environment = "prod"
node_group_capacity_type = "ON_DEMAND"
node_group_instance_types = ["t3.medium", "t3.large"]
node_group_desired_size = 3
node_group_max_size = 10
cluster_endpoint_public_access_cidrs = ["YOUR_OFFICE_IP/32"]
```

### Security Considerations

1. **Network Access**: Restrict `cluster_endpoint_public_access_cidrs` to your organization's IP ranges
2. **Node Access**: Consider enabling `remote_access` with specific security groups
3. **Encryption**: Enable encryption at rest for EBS volumes
4. **Compliance**: Add appropriate tags for DoD compliance requirements

## 📊 Monitoring and Logging

### CloudWatch Container Insights

Container Insights is enabled by default and provides:
- CPU and memory utilization metrics
- Network and disk I/O metrics
- Container-level logging

### EKS Control Plane Logging

The following log types are enabled:
- API server logs
- Audit logs
- Authenticator logs
- Controller manager logs
- Scheduler logs

## 💰 Cost Optimization

### Development Environment
- Use SPOT instances: `node_group_capacity_type = "SPOT"`
- Smaller instance types: `["t3.small"]`
- Lower node counts: `desired_size = 1`

### Production Environment
- Use Cluster Autoscaler for dynamic scaling
- Monitor CloudWatch metrics to optimize instance types
- Consider Fargate for serverless workloads

## 🔄 Maintenance

### Updating the Cluster

```bash
# Update Kubernetes version
terraform apply -var="kubernetes_version=1.32"

# Update node group configuration
terraform apply -var="node_group_desired_size=3"
```

### Backup and Disaster Recovery

1. **etcd Backups**: Automatic backups managed by AWS
2. **Application Data**: Backup PostgreSQL data using AWS RDS snapshots
3. **Configuration**: Store Kubernetes manifests in version control

## 🚨 Troubleshooting

### Common Issues

1. **Node Group Creation Fails**
   - Check IAM permissions
   - Verify subnet configuration
   - Ensure security groups allow communication

2. **Pods Can't Pull Images**
   - Verify ECR permissions
   - Check image URLs in deployments
   - Ensure nodes have internet access

3. **LoadBalancer Services Pending**
   - Check AWS Load Balancer Controller installation
   - Verify subnet tags for load balancer placement

### Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl describe node <node-name>

# Check pod logs
kubectl logs -f <pod-name> -n military-voting

# Check EKS cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug networking
kubectl run debug --image=busybox -it --rm -- /bin/sh
```

## 🗑️ Cleanup

To destroy the infrastructure:

```bash
# Delete Kubernetes resources first
kubectl delete -k k8s/

# Wait for LoadBalancers to be deleted, then destroy Terraform resources
terraform destroy
```

## 📚 Additional Resources

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
