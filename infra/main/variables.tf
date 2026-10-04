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

variable "image_tag" {
  description = "Tag of the app image in ECR to run (sha-<short commit SHA>)"
  type        = string
  default     = "sha-f7bd975"
}

variable "desired_count" {
  description = "Number of app tasks the ECS service keeps running"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "IPv4 address range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
