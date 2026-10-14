# Laravel Notes: DevOps Learning Project

[![tests](https://github.com/kazisohrabuddintitu/laravel-notes-devops/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kazisohrabuddintitu/laravel-notes-devops/actions/workflows/tests.yml)

A small notes app built with Laravel, Inertia.js and React. The app is deliberately simple: the point of this repo is the DevOps work around it. It is containerized with Docker, tested and deployed with GitHub Actions, and runs on AWS with infrastructure managed by Terraform.

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
| CI/CD             | GitHub Actions, OIDC to AWS (no stored keys)               |
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

The GitHub Actions workflow in `.github/workflows/tests.yml` runs on every pull request, on every push to `main`, and manually from the **Run workflow** button. A small `changes` job first checks which files changed, then `ci` and `docker` run in parallel, and on `main` the `deploy` job runs after both have passed:

| Job      | What it does                                                                                                                                         |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci`     | Formatting, linting, type checks, static analysis and tests, with the tests running against a PostgreSQL 18 service container                        |
| `docker` | Builds the production image (with layer caching), scans it with Trivy, and on `main` pushes that same scanned image to the GitHub Container Registry |
| `deploy` | On `main` only, after approval: copies the image to ECR, registers a new task definition revision, runs the migrations, and rolls out the new image  |

When a change only touches Markdown files, `ci`, `docker` and `deploy` are skipped. Skipped jobs count as passed, so documentation-only pull requests can still be merged.

### Deployment

```text
merge to main → ci + docker → approval (production) → image to ECR → new task definition → migrations → rolling update on ECS
```

- **No AWS keys in GitHub.** The job signs in with OpenID Connect (OIDC): GitHub issues a short-lived token for this repository and the `production` Environment, and AWS exchanges it for one-hour credentials of the `notes-app-github-deploy` role. That role can only push to the app's ECR repository and deploy the app's ECS service.
- **Manual approval.** The job uses the `production` GitHub Environment, which only accepts the `main` branch and waits for a required reviewer. When the AWS stack is not running, reject the pending deployment.
- **Migrations first.** They run as a one-off ECS task with the new image. If they fail, the deploy stops and the old version keeps running.
- **Zero-downtime rollout with automatic rollback.** ECS starts the new task before stopping the old one, and only sends traffic to it once the load balancer health check (`/up`) passes. If the new tasks keep failing, the deployment circuit breaker rolls back to the previous revision and the job fails.

Terraform creates the ECS service once; after that, the deploy job decides which task definition revision runs (`ignore_changes = [task_definition]` in `infra/main/ecs.tf`). Each deploy starts from the latest revision and only replaces the image, so environment changes made in Terraform go out with the next deploy.

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
| `infra/github`    | The GitHub OIDC provider and the IAM role the deploy job assumes. Has its own state, so it stays when `infra/main` is destroyed.                            |
| `infra/main`      | VPC with public and private subnets, security groups, ECR, RDS PostgreSQL, ECS Fargate (cluster, task definition, service) and an Application Load Balancer |

```text
Internet → ALB (public subnets) → ECS Fargate task → RDS PostgreSQL (private subnets)
```

Secrets never appear in the code, the plan or the state: RDS generates the database password and stores it in AWS Secrets Manager, the Laravel `APP_KEY` is stored in a Secrets Manager secret, and ECS injects both into the container when it starts.

Bring the stack up from scratch:

```bash
cd infra/main
terraform init

# 1. Create everything, but start no tasks yet: the new ECR repository is still empty
terraform apply -var desired_count=0

# 2. Store a new APP_KEY in Secrets Manager (the value is never printed)
aws secretsmanager put-secret-value --region eu-south-1 \
  --secret-id "$(terraform output -raw app_key_secret_arn)" \
  --secret-string "base64:$(openssl rand -base64 32)"

# 3. Deploy main: pushes the image to ECR, runs the migrations and updates the service
gh workflow run tests.yml --ref main     # then approve the deployment in the Actions tab

# 4. Start the app with the revision the deploy job registered
terraform apply
terraform output app_url
```

After that, every merge to `main` deploys after approval. To keep costs low there is no NAT gateway (tasks get a public IP, but only the load balancer can reach them), and the whole stack is removed with `terraform destroy` in `infra/main` when it is not needed. `infra/github` costs nothing and can stay.

## Workflow

`main` is protected: every change goes through a pull request, both the `ci` and `docker` checks must pass, and the branch must be up to date with `main` before it can be merged. A merged change reaches production only after the deployment is approved in the `production` Environment.

## Roadmap

- [x] Phase 0: AWS account setup (MFA, IAM admin user, budget alerts, CLI access without long-lived keys)
- [x] Phase 1: App, Git and GitHub
- [x] Phase 2: Docker (multi-stage image, Docker Compose)
- [x] Phase 3: CI pipeline (tests against PostgreSQL, image build, security scan, image publishing)
- [x] Phase 4: AWS fundamentals (VPC, security groups, EC2, ECR, RDS, ECS Fargate and ALB, built by hand in the console)
- [x] Phase 5: Infrastructure as Code with Terraform (VPC, ECS, RDS, ALB, state in S3, secrets in Secrets Manager)
- [x] Phase 6: Continuous deployment to AWS via GitHub OIDC (approval gate, migrations, zero-downtime rollout, automatic rollback)
- [ ] Phase 7: Secrets and environments
- [ ] Phase 8: AI note summaries with queues and Laravel Horizon
- [ ] Phase 9: Custom domain and HTTPS
- [ ] Phase 10: Monitoring and alerting
