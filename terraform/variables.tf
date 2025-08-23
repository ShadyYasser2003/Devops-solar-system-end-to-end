# ----------------------
# Variables Configuration
# ----------------------

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "solar-cluster"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "node_group_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 1
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "app_domain" {
  description = "Domain name for the application"
  type        = string
  default     = "solar.example.com"
}

variable "backend_image" {
  description = "Backend Docker image"
  type        = string
  default     = "shady203/vote-backend"
}

variable "frontend_image" {
  description = "Frontend Docker image"
  type        = string
  default     = "shady203/frontend123"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "postgres123"
  sensitive   = true
}

variable "storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "10Gi"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "voting-app"
    ManagedBy   = "terraform"
  }
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = "KEYPAIR"
}