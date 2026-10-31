variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile"
  type        = string
  default     = "aws-learning"
}

variable "admin_cidr" {
  description = "Public IPv4 address of my computer with /32"
  type        = string
}
