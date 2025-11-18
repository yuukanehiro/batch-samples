variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "batch-samples"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# VPC Settings
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

# RDS Settings
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage (GB)"
  type        = number
  default     = 20
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "general"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

# ECS Settings
variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECS task memory (MB)"
  type        = string
  default     = "512"
}

# Batch Schedule Settings
variable "sample_batch_schedule" {
  description = "Sample batch schedule expression (cron)"
  type        = string
  default     = "cron(0 2 * * ? *)" # 毎日午前2時（UTC）
}

variable "retry_batch_schedule" {
  description = "Retry batch schedule expression (cron)"
  type        = string
  default     = "cron(0 3 * * ? *)" # 毎日午前3時（UTC）
}

# Tenant Configuration
variable "tenants" {
  description = "Tenant configurations"
  type = list(object({
    id      = number
    code    = string
    name    = string
    db_name = string
  }))
  default = [
    { id = 1, code = "acme", name = "Acme Corporation", db_name = "1_acme" },
    { id = 2, code = "techcorp", name = "Tech Corp", db_name = "2_techcorp" },
    { id = 3, code = "finserv", name = "Financial Services Inc", db_name = "3_finserv" },
    { id = 4, code = "healthsys", name = "Health Systems Ltd", db_name = "4_healthsys" },
    { id = 5, code = "edutech", name = "Education Technology Group", db_name = "5_edutech" }
  ]
}

# Bastion Host Settings
variable "bastion_public_key" {
  description = "Public key for Bastion host SSH access"
  type        = string
}
