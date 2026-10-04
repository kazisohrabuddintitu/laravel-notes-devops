variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-south-1"
}

variable "project" {
  description = "Project name, used in resource names and the Project tag"
  type        = string
  default     = "notes-app"
}

variable "vpc_cidr" {
  description = "IPv4 address range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
