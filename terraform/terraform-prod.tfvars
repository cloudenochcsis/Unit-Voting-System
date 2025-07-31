# Production Configuration for Military Unit Voting System EKS Cluster
# This configuration is optimized for production deployment with high availability and performance

# AWS Configuration
aws_region  = "us-west-2"
environment = "prod"

# EKS Cluster Configuration
cluster_name       = "military-voting-system-prod"
kubernetes_version = "1.31"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# For production, restrict this to your organization's IP ranges
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Update with military network CIDR blocks

# Node Group Configuration - PRODUCTION OPTIMIZED
node_group_capacity_type   = "ON_DEMAND"      # Reliable for production workloads
node_group_instance_types  = ["t3.medium", "t3.large"]  # Production-grade instances
node_group_disk_size      = 50               # Adequate storage for production
node_group_desired_size   = 3                # Multi-node for high availability
node_group_max_size       = 10               # Allow scaling for peak loads
node_group_min_size       = 2                # Minimum for availability

# EKS Add-on Versions (use latest compatible versions)
ebs_csi_driver_version = "v1.35.0-eksbuild.1"
coredns_version       = "v1.11.3-eksbuild.1"
kube_proxy_version    = "v1.31.0-eksbuild.5"
vpc_cni_version       = "v1.18.5-eksbuild.1"

# Feature Flags - Production features enabled
enable_container_insights = true   # Enable monitoring for production
enable_irsa              = true
create_ecr_repositories  = true

# Additional Tags
additional_tags = {
  Owner          = "Military-IT-Division"
  CostCenter     = "Operations-Command"
  Environment    = "Production"
  Purpose        = "Unit-Voting-System-Production"
  Classification = "Unclassified"
  Mission        = "Training-Exercise-Operations"
  Compliance     = "DoD-Standards"
  Backup         = "Required"
}
