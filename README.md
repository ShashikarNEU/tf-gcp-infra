# GCP Infrastructure with Terraform

Infrastructure-as-Code (IaC) project that provisions and manages cloud networking resources on **Google Cloud Platform (GCP)** using **Terraform**. Covers VPC creation, subnet configuration, routing, firewall rules, Cloud SQL, Cloud Storage, and more — built for a production-grade cloud-native web application.

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure provisioning and state management |
| Google Cloud Platform | Cloud provider |
| gcloud CLI | Authentication and project configuration |
| GitHub Actions | CI/CD for infrastructure changes |

---

## Infrastructure Components

- **VPC (Virtual Private Cloud)** — Custom VPC with isolated network environment
- **Subnets** — Separate `webapp` and `db` subnets for application and database tiers
- **Routes** — Custom route to `0.0.0.0/0` via Internet Gateway for public traffic
- **Firewall Rules** — Ingress/egress rules to control traffic between subnets and the internet
- **Cloud SQL** — Managed MySQL instance for application database
- **Cloud Storage** — Object storage buckets for static assets and backups
- **VM Instances** — Compute Engine VMs running the application
- **Auto Scaling** — Managed Instance Groups with autoscaling policies
- **Load Balancer** — HTTP(S) Load Balancer for distributing traffic
- **Customer-Managed Encryption Keys (CMEK)** — Encryption for Cloud SQL and Storage

---

## Enabled GCP APIs

- Compute Engine API
- Cloud SQL Admin API
- Cloud Storage API + JSON API
- Cloud Logging & Monitoring API
- Cloud DNS API
- Service Management & Usage API
- BigQuery API
- Cloud Key Management Service (KMS) API

---

## Prerequisites

- [gcloud CLI](https://cloud.google.com/sdk/gcloud) installed and authenticated
- [Terraform](https://www.terraform.io/downloads.html) v1.0+ installed
- A GCP project with billing enabled
- Required APIs enabled in your GCP project

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/ShashikarNEU/tf-gcp-infra.git
cd tf-gcp-infra
```

### 2. Authenticate with GCP

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Apply Infrastructure

```bash
terraform apply
```

### 6. Tear Down

```bash
terraform destroy
```

---

## Project Structure

```
tf-gcp-infra/
├── main.tf              # Core infrastructure resources
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values (not committed)
├── vpc.tf               # VPC and subnet configuration
├── firewall.tf          # Firewall rules
├── sql.tf               # Cloud SQL instance
├── storage.tf           # Cloud Storage buckets
├── compute.tf           # VM instances and instance templates
└── README.md
```

---

## Key Design Decisions

- **No hardcoded values** — All configuration is driven by variables via `terraform.tfvars`
- **Separation of concerns** — Network, compute, database, and storage are in separate `.tf` files
- **Security** — Private subnets for the database tier, CMEK for encryption at rest
- **Scalability** — Managed instance groups with autoscaling for the application tier

---

## CI/CD

GitHub Actions workflows are configured to:
- Validate and lint Terraform on pull requests
- Apply infrastructure changes on merge to `main`

---

## Related Repositories

- [webapp](https://github.com/ShashikarNEU/webapp) — The Spring Boot application deployed on this infrastructure
- [serverless-fork](https://github.com/ShashikarNEU/serverless-fork) — Cloud Functions triggered by Pub/Sub events in this infrastructure
