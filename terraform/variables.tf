# Variables for Military Unit Voting System EKS Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "military-voting-system"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Group Configuration
variable "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_instance_types" {
  description = "List of instance types for the EKS Node Group"
  type        = list(string)
  default     = ["t3.micro"]  # Free Tier eligible: 750 hours/month
}

variable "node_group_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 8  # Minimal disk size for Free Tier (30GB total limit)
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1  # Single node for Free Tier cost optimization
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2  # Limit scaling for cost control
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

# EKS Add-on Versions
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver add-on"
  type        = string
  default     = "v1.35.0-eksbuild.1"
}

variable "coredns_version" {
  description = "Version of the CoreDNS add-on"
  type        = string
  default     = "v1.11.3-eksbuild.1"
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on"
  type        = string
  default     = "v1.31.0-eksbuild.5"
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI add-on"
  type        = string
  default     = "v1.18.5-eksbuild.1"
}

# Application-specific variables
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster"
  type        = bool
  default     = false  # Disabled by default to reduce CloudWatch costs
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "create_ecr_repositories" {
  description = "Create ECR repositories for application services"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
