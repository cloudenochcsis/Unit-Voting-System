# AWS Free Tier Optimized Configuration for Military Unit Voting System
# This configuration minimizes costs while staying within Free Tier limits where possible

# AWS Configuration
aws_region  = "us-east-1"  # Often has better Free Tier availability
environment = "freetier"

# EKS Cluster Configuration
cluster_name       = "military-voting-freetier"
kubernetes_version = "1.31"

# Network Configuration - Smaller CIDR for cost efficiency
vpc_cidr = "10.0.0.0/16"

# Restrict access for security and reduce data transfer costs
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Update with your IP for security

# Node Group Configuration - FREE TIER OPTIMIZED
node_group_capacity_type   = "ON_DEMAND"  # More predictable for Free Tier
node_group_instance_types  = ["t3.micro"]  # FREE TIER ELIGIBLE (750 hours/month)
node_group_disk_size      = 8             # Minimal disk size (Free Tier: 30GB total)
node_group_desired_size   = 1             # SINGLE NODE to stay in Free Tier
node_group_max_size       = 1             # NO SCALING to control costs
node_group_min_size       = 1             # Keep at least one node

# EKS Add-on Versions (use latest compatible versions)
ebs_csi_driver_version = "v1.35.0-eksbuild.1"
coredns_version       = "v1.11.3-eksbuild.1"
kube_proxy_version    = "v1.31.0-eksbuild.5"
vpc_cni_version       = "v1.18.5-eksbuild.1"

# Feature Flags - Minimize costs
enable_container_insights = false  # Reduces CloudWatch costs
enable_irsa              = true
create_ecr_repositories  = true

# Additional Tags
additional_tags = {
  Owner       = "Military-IT-Division"
  CostCenter  = "Training-Operations"
  Environment = "Development"
  Purpose     = "Unit-Voting-System-Demo"
  Classification = "Unclassified"
  Mission     = "Training-Exercise-Planning"
}
