variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-2"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "Abhinav"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "spendwise-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. null = the current EKS default."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.21.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per Availability Zone (EKS needs at least two AZs)."
  type        = list(string)
  default     = ["10.21.1.0/24", "10.21.2.0/24"]
}

variable "node_instance_type" {
  description = "Worker node instance type."
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Number of worker nodes."
  type        = number
  default     = 1
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint, e.g. your own IP: [\"203.0.113.10/32\"] (curl -s https://checkip.amazonaws.com)."
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Give at least one CIDR and do not open the API to 0.0.0.0/0."
  }
}
