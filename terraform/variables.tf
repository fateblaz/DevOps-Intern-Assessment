variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "name_prefix" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "sync-system"
}

variable "vpc_cidr" {
  description = "VPC CIDR range"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "ssh_key_name" {
  description = "Existing SSH key pair name"
  type        = string
}

variable "admin_cidr" {
  description = "IP/CIDR allowed to SSH and connect via Compass (ssh tunnel recommended)"
  type        = string
}

variable "ami" {
  description = "Amazon Linux 2 AMI"
  type        = string
  default     = "ami-03695d52f0d883f65"
}

variable "docker_image" {
  description = "Docker image to run MongoDB"
  type        = string
  default     = "mongo:6.0"
}

variable "primary_instance_type" {
  description = "EC2 instance type for primary node"
  type        = string
  default     = "t2.micro"
}

variable "secondary_instance_type" {
  description = "EC2 instance type for secondary node"
  type        = string
  default     = "t2.micro"
}

variable "staging_instance_type" {
  description = "EC2 instance type for staging node"
  type        = string
  default     = "t2.micro"
}

variable "data_volume_size_gb" {
  description = "EBS data volume size in GB"
  type        = number
  default     = 8
}

variable "data_device" {
  description = "Device name for attached data EBS volume"
  type        = string
  default     = "/dev/xvdf"
}

variable "admin_ssm_user" {
  description = "SSM parameter name holding Mongo admin username"
  type        = string
  default     = "/mongo/admin"
}

variable "admin_ssm_password" {
  description = "SSM parameter name holding Mongo admin password"
  type        = string
  default     = "/mongo/admin/password"
}


variable "tfstate_bucket" {
  description = "S3 bucket name for Terraform state (bootstrap will create)"
  type        = string
  default     = ""
}

variable "tfstate_lock_table" {
  description = "DynamoDB table name for TF lock"
  type        = string
  default     = "terraform-locks-sync-system"
}
