# Laravel Notes: DevOps Learning Project

[![tests](https://github.com/kazisohrabuddintitu/laravel-notes-devops/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kazisohrabuddintitu/laravel-notes-devops/actions/workflows/tests.yml)

A small notes app built with Laravel, Inertia.js and React. The app is deliberately simple: the point of this repo is the DevOps work around it. It will be containerized with Docker, tested and deployed with GitHub Actions, and run on AWS with infrastructure managed by Terraform.

## Features

- Registration, login and password confirmation (Laravel React starter kit)
- Notes CRUD: each user sees and manages only their own notes

## Tech stack

| Layer             | Technology                                                 |
| ----------------- | ---------------------------------------------------------- |
| Backend           | Laravel 13, PHP 8.5                                        |
| Frontend          | Inertia.js v3, React 19, TypeScript, Tailwind CSS          |
| Database          | PostgreSQL 18                                              |
| Testing & quality | Pest, PHPStan (Larastan), Pint                             |
| CI                | GitHub Actions                                             |
| Containers        | Docker, Docker Compose, serversideup/php (PHP-FPM + nginx) |
| Infrastructure    | Terraform, AWS (VPC, ECR, RDS, ECS Fargate, ALB)           |

## Run with Docker

Requirements: Docker and a `.env` file containing an `APP_KEY` (see step 2 below if you don't have one yet).

```bash
docker compose up -d --build
docker compose exec app php artisan migrate
```

Open http://localhost:8000 and register an account.

The `app` service runs the production-style image built from the `Dockerfile` (PHP-FPM + nginx, with compiled frontend assets), and the `postgres` service runs PostgreSQL 18. The database is only reachable from the `app` container and stores its data in the `pgdata` volume.

Useful commands:

```bash
docker compose ps              # status and health of the containers
docker compose logs -f app     # follow the application logs
docker compose exec app bash   # open a shell inside the app container
docker compose down            # stop and remove the containers (the data volume is kept)
```

## Run locally (for development)

Requirements: PHP 8.5, Composer, Node 22 and Docker.

1. Start PostgreSQL in Docker:

    ```bash
    docker run -d \
      --name notes-postgres \
      -e POSTGRES_USER=notes \
      -e POSTGRES_PASSWORD=secret \
      -e POSTGRES_DB=notes \
      -p 5432:5432 \
      -v notes-pgdata:/var/lib/postgresql \
      postgres:18
    ```

2. Install dependencies and create your environment file:

    ```bash
    composer install
    npm install
    cp .env.example .env
    php artisan key:generate
    ```

3. Point `.env` to the database:

    ```env
    DB_CONNECTION=pgsql
    DB_HOST=127.0.0.1
    DB_PORT=5432
    DB_DATABASE=notes
    DB_USERNAME=notes
    DB_PASSWORD=secret
    ```

4. Run the migrations and start the app:

    ```bash
    php artisan migrate
    composer run dev
    ```

    Open http://localhost:8000 and register an account.

## Checks

Run the same checks as CI (formatting, linting, type checks, static analysis and tests):

```bash
composer ci:check
```

## CI/CD pipeline

The GitHub Actions workflow in `.github/workflows/tests.yml` runs on every pull request and on every push to `main`. A small `changes` job first checks which files changed, then two jobs run in parallel:

| Job      | What it does                                                                                                                    |
| -------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `ci`     | Formatting, linting, type checks, static analysis and tests, with the tests running against a PostgreSQL 18 service container   |
| `docker` | Builds the production image (with layer caching), scans it with Trivy, and on `main` pushes it to the GitHub Container Registry |

When a change only touches Markdown files, `ci` and `docker` are skipped. Skipped jobs count as passed, so documentation-only pull requests can still be merged.

Trivy results are uploaded to the repository's **Security → Code scanning** tab, and the build fails if the image contains a critical vulnerability that has a fix available.

Images from `main` are published as:

```bash
docker pull ghcr.io/kazisohrabuddintitu/laravel-notes-devops:latest        # newest main
docker pull ghcr.io/kazisohrabuddintitu/laravel-notes-devops:sha-<commit>  # a specific commit
```

## Infrastructure (Terraform)

The AWS infrastructure in `eu-south-1` is defined with Terraform in `infra/`:

| Folder            | What it creates                                                                                                                                             |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `infra/bootstrap` | The S3 bucket that stores the Terraform state (versioned, encrypted, private). Applied once, with local state.                                              |
| `infra/main`      | VPC with public and private subnets, security groups, ECR, RDS PostgreSQL, ECS Fargate (cluster, task definition, service) and an Application Load Balancer |

```text
Internet → ALB (public subnets) → ECS Fargate task → RDS PostgreSQL (private subnets)
```

Secrets never appear in the code, the plan or the state: RDS generates the database password and stores it in AWS Secrets Manager, the Laravel `APP_KEY` is stored in a Secrets Manager secret, and ECS injects both into the container when it starts.

Bring the stack up:

```bash
cd infra/main
terraform init
terraform apply

# Push an image built by CI
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region eu-south-1 | docker login --username AWS --password-stdin ${ECR_URL%/*}
docker pull --platform linux/amd64 ghcr.io/kazisohrabuddintitu/laravel-notes-devops:sha-<commit>
docker tag ghcr.io/kazisohrabuddintitu/laravel-notes-devops:sha-<commit> ${ECR_URL}:sha-<commit>
docker push ${ECR_URL}:sha-<commit>

# Store a new APP_KEY in Secrets Manager (the value is never printed)
aws secretsmanager put-secret-value --region eu-south-1 \
  --secret-id "$(terraform output -raw app_key_secret_arn)" \
  --secret-string "$(docker run --rm --platform linux/amd64 -e SHOW_WELCOME_MESSAGE=false ${ECR_URL}:sha-<commit> php artisan key:generate --show | tail -n 1)"

# Run the migrations as a one-off task, then open the app
aws ecs run-task --region eu-south-1 --cluster "$(terraform output -raw ecs_cluster_name)" \
  --launch-type FARGATE --task-definition "$(terraform output -raw task_definition_arn)" \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json public_subnet_ids | tr -d '[]" ')],securityGroups=[$(terraform output -raw app_security_group_id)],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"app","command":["php","artisan","migrate","--force"]}]}'
terraform output app_url
```

The image tag defaults to the `image_tag` variable in `infra/main/variables.tf`. To keep costs low there is no NAT gateway (tasks get a public IP, but only the load balancer can reach them), and the whole stack is removed with `terraform destroy` when it is not needed.

## Workflow

`main` is protected: every change goes through a pull request, both the `ci` and `docker` checks must pass, and the branch must be up to date with `main` before it can be merged.

## Roadmap

- [x] Phase 0: AWS account setup (MFA, IAM admin user, budget alerts, CLI access without long-lived keys)
- [x] Phase 1: App, Git and GitHub
- [x] Phase 2: Docker (multi-stage image, Docker Compose)
- [x] Phase 3: CI pipeline (tests against PostgreSQL, image build, security scan, image publishing)
- [x] Phase 4: AWS fundamentals (VPC, security groups, EC2, ECR, RDS, ECS Fargate and ALB, built by hand in the console)
- [x] Phase 5: Infrastructure as Code with Terraform (VPC, ECS, RDS, ALB, state in S3, secrets in Secrets Manager)
- [ ] Phase 6: Continuous deployment to AWS via GitHub OIDC
- [ ] Phase 7: Secrets and environments
- [ ] Phase 8: AI note summaries with queues and Laravel Horizon
- [ ] Phase 9: Custom domain and HTTPS
- [ ] Phase 10: Monitoring and alerting
