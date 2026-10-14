terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Same bucket as infra/main, different key: this layer has its own state, so
  # destroying infra/main never touches the deploy role.
  backend "s3" {
    bucket       = "notes-app-tfstate-361964630531"
    key          = "github/terraform.tfstate"
    region       = "eu-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
