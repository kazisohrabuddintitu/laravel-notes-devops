# Private registry for the app image. Tags are immutable, so a tag such as
# sha-cff1ecd always refers to exactly one image and deploys happen by commit SHA.

resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "IMMUTABLE"

  # Lets `terraform destroy` remove the repository even when it still holds
  # images. Fine for this learning setup; production would keep it false.
  force_delete = true

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep the newest 10 images and delete older ones automatically.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Scanning is configured for the whole registry (account + region), not per
# repository: basic scanning (free) of every image on push.
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "BASIC"

  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}
