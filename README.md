# To-do app — Terraform + Docker + CI/CD + monitoring

A small to-do list app used as a vehicle to demonstrate a real, end-to-end
DevOps workflow: infrastructure as code, containerization, CI/CD, and
monitoring — all on AWS.

## Architecture

```
Code push (GitHub)
        |
        v
GitHub Actions CI/CD  --- builds Docker image, pushes to Amazon ECR
        |
        v
AWS Systems Manager (SSM) Run Command  --- no SSH keys, no open port 22
        |
        v
EC2 instance running Docker
        |
        +--> todo-app container (port 5000)
        +--> Prometheus (scrapes /metrics from the app)
        +--> Grafana (dashboards on port 3000)
```

Infrastructure (VPC, subnet, security group, EC2, ECR repo, IAM role) is
provisioned once with Terraform. After that, every `git push` to `main`
rebuilds the image and redeploys automatically.

## Why these choices

- **Terraform** — infrastructure is defined in code and version-controlled,
  instead of clicked together in the AWS console. `terraform plan` shows
  exactly what will change before it happens.
- **SSM instead of SSH** — GitHub Actions never holds a private key, and the
  EC2 instance never opens port 22 to the internet. It only trusts commands
  that come through AWS IAM, which is how this is done in production
  environments.
- **Prometheus + Grafana alongside CloudWatch** — the app exposes a
  `/metrics` endpoint (request counts, latency, tasks created/completed).
  Prometheus scrapes it, Grafana visualizes it. This is a different,
  commonly-requested monitoring stack from CloudWatch, and it's fully
  self-hosted so it's easy to demo.
- **Remote Terraform state (S3 + DynamoDB)** — state isn't just a local file
  that only exists on one machine; it's shared, versioned, and locked so two
  `terraform apply` runs can't race each other.
- **Two alert rules, not a dozen** — `AppDown` (the app stops responding)
  and `HighErrorRate` (>5% of requests are 5xx over 5 minutes). A to-do app
  has no meaningful business metrics to alert on, so these are the same two
  alerts you'd reach for on almost any service — deliberately kept to two so
  they're easy to explain and to demo triggering.

## Repo structure

```
app/                    Flask to-do app + Dockerfile
terraform/              VPC, EC2, security group, ECR, IAM role
terraform/bootstrap/    One-time setup: S3 bucket + DynamoDB table for remote state
.github/workflows/      CI/CD pipeline (build -> ECR -> SSM deploy)
monitoring/             Prometheus scrape config + alert rules
docker-compose.yml      Runs app + Prometheus + Grafana together on EC2
```

## Setup steps

1. **Bootstrap remote state** (once, before anything else)
   ```
   cd terraform/bootstrap
   terraform init
   terraform apply
   ```
   Copy the `state_bucket_name` output into `terraform/backend.tf`.

2. **Provision infrastructure**
   ```
   cd terraform
   terraform init -migrate-state
   terraform apply
   ```
   Note the outputs: `instance_id`, `ecr_repository_url`, `app_url`, `grafana_url`.

3. **Add GitHub repo secrets** (Settings -> Secrets and variables -> Actions)
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — an IAM user with ECR push
     and `ssm:SendCommand` permissions
   - `EC2_INSTANCE_ID` — from the Terraform output

4. **Push to `main`** — GitHub Actions builds the image, pushes it to ECR,
   and deploys it to EC2 via SSM automatically.

5. **Start monitoring** — SSH is disabled on purpose, so run this once via
   SSM Session Manager (`aws ssm start-session --target <instance-id>`) or
   add it as a one-time `user_data` step:
   ```
   docker compose up -d prometheus grafana
   ```
   Then open `http://<public-ip>:3000` (Grafana, login admin/admin) and add
   Prometheus (`http://prometheus:9090`) as a data source. Alert rules in
   `monitoring/alerts.yml` are loaded automatically — check the "Alerts" tab
   in Prometheus at `http://<public-ip>:9090/alerts` to see them.

6. **Visit the app** at `http://<public-ip>:5000`.

## Interview talking points

- Why Terraform over manual console setup (repeatability, code review,
  destroy/recreate cleanly)
- Why SSM over SSH for deployment (no key management, no open inbound port,
  IAM-scoped permissions)
- What the CI/CD pipeline actually does at each stage, and what happens if a
  step fails
- What the `/metrics` endpoint exposes and why those specific metrics were
  chosen
- What you'd add next: multiple environments (staging/prod), a load
  balancer instead of a single EC2 instance, alerting rules in Prometheus
