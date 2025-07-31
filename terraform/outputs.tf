# Outputs for Military Unit Voting System EKS Infrastructure

# Cluster Information
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.military_voting_cluster.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.military_voting_cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.military_voting_cluster.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.military_voting_cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.eks_cluster_role.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.military_voting_cluster.certificate_authority[0].data
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that is created by Amazon EKS for the cluster"
  value       = aws_eks_cluster.military_voting_cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = aws_eks_cluster.military_voting_cluster.version
}

# OIDC Provider
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.military_voting_cluster.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# Node Group Information
output "node_groups" {
  description = "EKS node groups"
  value = {
    military_voting_nodes = {
      arn           = aws_eks_node_group.military_voting_nodes.arn
      status        = aws_eks_node_group.military_voting_nodes.status
      capacity_type = aws_eks_node_group.military_voting_nodes.capacity_type
      instance_types = aws_eks_node_group.military_voting_nodes.instance_types
      ami_type      = aws_eks_node_group.military_voting_nodes.ami_type
      node_role_arn = aws_eks_node_group.military_voting_nodes.node_role_arn
    }
  }
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC where the cluster and its nodes will be provisioned"
  value       = aws_vpc.military_voting_vpc.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.military_voting_vpc.cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.military_voting_nat[*].id
}

# ECR Repository Information
output "ecr_repositories" {
  description = "ECR repository URLs for application services"
  value = {
    vote_service   = aws_ecr_repository.vote_service.repository_url
    result_service = aws_ecr_repository.result_service.repository_url
    worker_service = aws_ecr_repository.worker_service.repository_url
  }
}

# Kubectl Configuration Command
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.military_voting_cluster.name}"
}

# Application Deployment Information
output "deployment_info" {
  description = "Information needed for application deployment"
  value = {
    cluster_name = aws_eks_cluster.military_voting_cluster.name
    region       = var.aws_region
    ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    
    # Container image URLs for Kubernetes deployments
    container_images = {
      vote_service   = "${aws_ecr_repository.vote_service.repository_url}:latest"
      result_service = "${aws_ecr_repository.result_service.repository_url}:latest"
      worker_service = "${aws_ecr_repository.worker_service.repository_url}:latest"
    }
    
    # LoadBalancer service endpoints (will be available after K8s deployment)
    service_endpoints = {
      vote_service   = "http://<LOAD_BALANCER_URL>:80"
      result_service = "http://<LOAD_BALANCER_URL>:80"
    }
  }
}

# Cost Optimization Information
output "cost_optimization" {
  description = "Cost optimization recommendations"
  value = {
    node_group_capacity_type = var.node_group_capacity_type
    instance_types          = var.node_group_instance_types
    scaling_config = {
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size
    }
    recommendations = [
      "Consider using SPOT instances for development environments",
      "Monitor CloudWatch metrics to optimize node group scaling",
      "Use Cluster Autoscaler for automatic scaling based on demand",
      "Consider using Fargate for serverless container execution"
    ]
  }
}
