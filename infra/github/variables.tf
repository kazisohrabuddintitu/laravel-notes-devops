variable "aws_region" {
  description = "AWS region of the resources the deploy role manages"
  type        = string
  default     = "eu-south-1"
}

variable "project" {
  description = "Project name, used in resource names and the Project tag"
  type        = string
  default     = "notes-app"
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deploy role"
  type        = string
  default     = "kazisohrabuddintitu/laravel-notes-devops"
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role"
  type        = string
  default     = "production"
}
