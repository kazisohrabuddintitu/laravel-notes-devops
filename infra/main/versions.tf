terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the bucket created by infra/bootstrap. Backend settings
  # cannot use variables, so the values are written out here.
  backend "s3" {
    bucket       = "notes-app-tfstate-361964630531"
    key          = "main/terraform.tfstate"
    region       = "eu-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
