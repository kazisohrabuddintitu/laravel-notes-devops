# Laravel Notes: DevOps Learning Project

A small notes app built with Laravel, Inertia.js and React. The app is deliberately simple: the point of this repo is the DevOps work around it. It will be containerized with Docker, tested and deployed with GitHub Actions, and run on AWS with infrastructure managed by Terraform.

## Features

- Registration, login and password confirmation (Laravel React starter kit)
- Notes CRUD: each user sees and manages only their own notes

## Tech stack

| Layer             | Technology                                        |
| ----------------- | ------------------------------------------------- |
| Backend           | Laravel 13, PHP 8.5                               |
| Frontend          | Inertia.js v3, React 19, TypeScript, Tailwind CSS |
| Database          | PostgreSQL 18                                     |
| Testing & quality | Pest, PHPStan (Larastan), Pint                    |
| CI                | GitHub Actions                                    |

## Run locally

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

## Workflow

`main` is protected: every change goes through a pull request, and the `ci` check must pass before it can be merged.

## Roadmap

- [x] Phase 1: App, Git and GitHub
- [ ] Phase 2: Docker (multi-stage image, Docker Compose)
- [ ] Phase 3: CI pipeline (tests against PostgreSQL, image build, security scan)
- [ ] Phase 4: AWS fundamentals
- [ ] Phase 5: Infrastructure as Code with Terraform (VPC, ECS, RDS, ALB)
- [ ] Phase 6: Continuous deployment to AWS via GitHub OIDC
- [ ] Phase 7: Secrets and environments
- [ ] Phase 8: AI note summaries with queues and Laravel Horizon
- [ ] Phase 9: Custom domain and HTTPS
- [ ] Phase 10: Monitoring and alerting
