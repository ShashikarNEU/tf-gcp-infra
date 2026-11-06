# GCP Infrastructure with Terraform

Terraform for a cloud-native web app on **Google Cloud**: a private VPC, an autoscaled VM fleet behind a global HTTPS load balancer, a private Cloud SQL (MySQL) database with customer-managed encryption keys, and a Pub/Sub-triggered Cloud Function that sends email verification links.

The app itself lives in [webapp](https://github.com/ShashikarNEU/webapp) (Spring Boot, baked into VM images with Packer). The function lives in [serverless-fork](https://github.com/ShashikarNEU/serverless-fork).

---

## Architecture

```
User ──> Cloud DNS (A record) ──> Global HTTPS LB (Google-managed cert)
                                        │  only from Google Front End ranges
                                        v
              ┌──────────────────── VPC (custom mode) ────────────────────┐
              │  webapp subnet: regional MIG (no external IPs)            │
              │    autoscaler on CPU, auto-healing on /healthz            │
              │    boot disks encrypted with CMEK                         │
              │        │ JDBC (private IP)                                │
              │        v                                                  │
              │  Cloud SQL MySQL: private IP only, regional HA, PITR, CMEK│
              │        ^                                                  │
              │        │ Serverless VPC Access connector                  │
              │  Cloud Function (gen2, Java) <── Eventarc <── Pub/Sub     │
              │                                    ^ published by the app │
              │  Cloud Router + Cloud NAT for outbound internet           │
              └───────────────────────────────────────────────────────────┘
  Secret Manager (DB creds, Mailgun key) · Cloud KMS (3 CMEKs) · Cloud Monitoring alerts
```

| AWS equivalent, for reference | |
|---|---|
| Cloud DNS + global HTTPS LB + managed cert | Route 53 alias + ALB + ACM |
| Regional MIG + autoscaler | Auto Scaling Group across AZs |
| Cloud SQL regional, private IP | RDS Multi-AZ in private subnets |
| Pub/Sub + Cloud Function | SNS/SQS + Lambda |
| Cloud NAT | NAT Gateway |
| Secret Manager / Cloud KMS | Secrets Manager / KMS |
| Workload Identity Federation | IAM OIDC provider for GitHub Actions |

---

## Files

| File | What it provisions |
|------|--------------------|
| `versions.tf` | Terraform + provider versions, GCS remote state backend |
| `providers.tf` | `google` and `google-beta` providers |
| `network.tf` | VPC, subnets, default route, Cloud Router + NAT, Private Services Access, firewall, VPC connector |
| `kms.tf` | Key ring and 3 rotating CMEKs (VM disks, bucket, Cloud SQL) + service-agent access |
| `database.tf` | Cloud SQL MySQL (private IP, HA, backups + binlog for PITR), database, user, generated password |
| `secrets.tf` | Secret Manager secrets for DB settings and the Mailgun key, read access for the app service account |
| `compute.tf` | Instance template (no external IP, CMEK disk, boot script), health check, regional MIG, autoscaler |
| `scripts/startup.sh.tftpl` | VM boot script: reads DB settings from Secret Manager and starts the app |
| `loadbalancer.tf` | Global forwarding rule, HTTPS proxy, URL map, backend service, managed SSL cert |
| `dns.tf` | A record for the domain in an existing Cloud DNS zone |
| `pubsub.tf` | `verify-email` topic |
| `functions.tf` | Source bucket (CMEK) and the Cloud Function with secrets mounted from Secret Manager |
| `iam.tf` | Project roles for the app and CI service accounts (non-authoritative `iam_member`) |
| `monitoring.tf` | Alert policies: LB 5xx rate, p99 latency, fleet CPU, function errors |
| `wif.tf` | Workload Identity Federation pool/provider for GitHub Actions |
| `outputs.tf` | LB IP, DB private IP, MIG name, VM KMS key, WIF provider |
| `moved.tf` | `moved` / `removed` blocks so existing state survives the refactor |
| `variables.tf` | Inputs (values go in an untracked `*.tfvars`) |

---

## Design decisions

- **No public IPs on VMs.** Ingress comes only through the load balancer. The firewall allows just the app and health-check ports from Google Front End ranges (`130.211.0.0/22`, `35.191.0.0/16`). Outbound traffic uses Cloud NAT. Google APIs are reached via Private Google Access.
- **Database is private.** Cloud SQL has no public IP and is reachable only over Private Services Access. Regional availability gives a standby in another zone, and binary logging enables point-in-time recovery.
- **Secrets never sit in metadata or Git.** VMs fetch DB settings from Secret Manager at boot with their service account. The function gets the DB password and Mailgun key as Secret Manager-backed env vars. The Mailgun key is added outside Terraform so it never lands in state.
- **CMEK everywhere data rests.** Separate rotating keys for VM disks, the bucket and Cloud SQL, each usable only by its own Google service agent.
- **Immutable deploys.** Terraform creates the initial template and MIG. After that, the webapp CI bakes a new image, creates a new template and rolls the MIG. `ignore_changes = [version]` stops Terraform from rolling it back.
- **Keyless CI.** GitHub Actions authenticates with Workload Identity Federation (short-lived tokens) instead of a stored service-account key.

---

## Prerequisites

- Terraform **>= 1.7** (uses `removed` blocks) and the gcloud CLI
- A GCP project with billing and these APIs enabled: Compute, Cloud SQL Admin, Service Networking, Cloud KMS, Secret Manager, Cloud DNS, Cloud Storage, Pub/Sub, Cloud Functions, Cloud Run, Cloud Build, Artifact Registry, Eventarc, Serverless VPC Access, Cloud Logging, Cloud Monitoring, IAM, IAM Service Account Credentials, Security Token Service
- An existing Cloud DNS managed zone for your domain
- A GCS bucket for Terraform state
- The VM service account (`email`) with scopes including `https://www.googleapis.com/auth/cloud-platform`, so it can read Secret Manager

---

## Usage

```bash
gcloud auth application-default login

terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="prefix=tf-gcp-infra"

terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars

# One time: store the Mailgun key (kept out of Terraform state)
printf '%s' "<mailgun-key>" | gcloud secrets versions add mailgun-api-key --data-file=-
```

New inputs to set in your `*.tfvars`: `mailgun_domain`, `verify_base_url` (e.g. `https://your-domain/v1/user/verify`), optionally `alert_email`, `sql_availability_type`, `github_owner`, `github_repositories`.

**Migrating from the old single-file version:** the old state was local. Run `terraform init -migrate-state` with the backend config above to copy it into GCS. `moved.tf` maps the old secret resources to their new addresses and drops the old authoritative IAM binding from state without deleting any grants. Review `terraform plan` before applying: the firewall rules and instance template are intentionally replaced.

---

## CI (GitHub Actions)

On every pull request to `main`: `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`.

After applying, set these GitHub secrets on the webapp repo so its workflows authenticate keylessly:

| Secret | Value |
|--------|-------|
| `WIF_PROVIDER` | `terraform output -raw workload_identity_provider` |
| `WIF_SERVICE_ACCOUNT` | the CI service account email (`email_workflow`) |

---

## Related Repositories

- [webapp](https://github.com/ShashikarNEU/webapp): Spring Boot API, Packer image, deploy pipeline
- [serverless-fork](https://github.com/ShashikarNEU/serverless-fork): email verification Cloud Function
