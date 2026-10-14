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
  description = "GitHub repository allowed to assume the deploy role, as it appears in the OIDC sub claim"
  type        = string
  # Immutable subject format: owner@owner_id/repo@repo_id. The IDs never
  # change, so a deleted or renamed repo cannot be recreated under the same
  # name to get this role. Check with:
  # gh api repos/OWNER/REPO/actions/oidc/customization/sub
  default = "kazisohrabuddintitu@86562061/laravel-notes-devops@1388242293"
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role"
  type        = string
  default     = "production"
}
