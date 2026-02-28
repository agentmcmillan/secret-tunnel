# AWS Region Configuration
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# EC2 Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for VPN server"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8
}

variable "ssh_key_name" {
  description = "Name of the AWS SSH key pair for EC2 access (REQUIRED - must exist in AWS)"
  type        = string
}

# Network Security Configuration
variable "admin_ip" {
  description = "IP address or CIDR block allowed SSH access (SECURITY: restrict to your IP!)"
  type        = string
  default     = "0.0.0.0/0"
}

# Headscale Configuration
variable "headscale_version" {
  description = "Version of Headscale to install"
  type        = string
  default     = "0.28.0"
}

variable "headscale_domain" {
  description = "Domain name for Headscale (leave empty to use Elastic IP)"
  type        = string
  default     = ""
}

# Auto-Stop Configuration
variable "idle_timeout_minutes" {
  description = "Minutes of idle time before auto-stopping instance"
  type        = number
  default     = 60
}

variable "idle_check_rate_minutes" {
  description = "How often to check for idle instances (minutes)"
  type        = number
  default     = 5
}

# Tagging Configuration
variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "SecretTunnel"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

# API Gateway Configuration
variable "api_throttle_rate_limit" {
  description = "API Gateway steady-state request rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst request limit"
  type        = number
  default     = 20
}

# Stealth Mode Configuration
variable "enable_stunnel" {
  description = "Enable stunnel TCP wrapper for WireGuard (stealth mode over TLS on TCP 443)"
  type        = bool
  default     = false
}
