# Military Unit Voting System - EKS Cluster Provisioning
# This Terraform configuration provisions an EKS cluster optimized for the voting application

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Military-Unit-Voting-System"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# VPC for EKS cluster
resource "aws_vpc" "military_voting_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "military_voting_igw" {
  vpc_id = aws_vpc.military_voting_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnets for Load Balancers
resource "aws_subnet" "public" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  vpc_id                  = aws_vpc.military_voting_vpc.id
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets for EKS nodes
resource "aws_subnet" "private" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  vpc_id            = aws_vpc.military_voting_vpc.id

  tags = {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateways for private subnet internet access
resource "aws_eip" "nat" {
  count = 2
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.military_voting_igw]

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "military_voting_nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.military_voting_igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.military_voting_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.military_voting_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.military_voting_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.military_voting_nat[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group for EKS cluster
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = aws_vpc.military_voting_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "military_voting_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Enable EKS Cluster logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# EKS Node Group
resource "aws_eks_node_group" "military_voting_nodes" {
  cluster_name    = aws_eks_cluster.military_voting_cluster.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = var.node_group_capacity_type
  instance_types = var.node_group_instance_types
  disk_size      = var.node_group_disk_size

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "${var.cluster_name}-nodes"
  }
}

# ECR Repository for Vote Service
resource "aws_ecr_repository" "vote_service" {
  name                 = "${var.cluster_name}/vote-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.cluster_name}-vote-service"
  }
}

# ECR Repository for Result Service
resource "aws_ecr_repository" "result_service" {
  name                 = "${var.cluster_name}/result-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.cluster_name}-result-service"
  }
}

# ECR Repository for Worker Service
resource "aws_ecr_repository" "worker_service" {
  name                 = "${var.cluster_name}/worker-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.cluster_name}-worker-service"
  }
}

# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

# OIDC Identity Provider for EKS
data "tls_certificate" "eks" {
  url = aws_eks_cluster.military_voting_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.military_voting_cluster.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-eks-irsa"
  }
}

# EKS Add-on: EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.military_voting_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
  resolve_conflicts        = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.military_voting_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-ebs-csi"
  }
}

# EKS Add-on: CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.military_voting_cluster.name
  addon_name        = "coredns"
  addon_version     = var.coredns_version
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.military_voting_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-coredns"
  }
}

# EKS Add-on: kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.military_voting_cluster.name
  addon_name        = "kube-proxy"
  addon_version     = var.kube_proxy_version
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.military_voting_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-kube-proxy"
  }
}

# EKS Add-on: VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.military_voting_cluster.name
  addon_name        = "vpc-cni"
  addon_version     = var.vpc_cni_version
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.military_voting_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }
}
