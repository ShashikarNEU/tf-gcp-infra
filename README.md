### Setting up Infrastructure on Google Cloud Platform using Terraform

This repository contains Terraform configurations to set up networking resources such as Virtual Private Cloud (VPC), subnets, routes, etc., on Google Cloud Platform (GCP).

#### Requirements

- [gcloud CLI](https://cloud.google.com/sdk/gcloud) installed and configured on your development machine.
- [Terraform](https://www.terraform.io/downloads.html) installed on your machine.
- Enable required GCP services/APIs in your project. (Google Compute Engine API is enabled)

#### Getting Started

1. **Clone Repository**: Clone this repository to your local machine.

    ```bash
    git clone https://github.com/your-username/tf-gcp-infra.git
    ```

2. **Navigate to Repository**: Enter the repository directory.

    ```bash
    cd tf-gcp-infra
    ```

3. **Set up gcloud CLI**: Ensure that the gcloud CLI is installed and authenticated.

    ```bash
    gcloud auth login
    ```

4. **Set up Terraform**: Initialize Terraform configurations.

    ```bash
    terraform init
    ```

#### Infrastructure Setup

1. **Create VPC and Subnets**: Terraform will create a Virtual Private Cloud (VPC) with two subnets: `webapp` and `db`.

2. **Configure Route**: Terraform will add a route to `0.0.0.0/0` with the next hop to Internet Gateway and attach it to your VPC.

3. **No Hardcoded Values**: Ensure that no values are hardcoded in the Terraform configuration files.

#### Usage

1. **Plan Infrastructure**: View the execution plan to understand what Terraform will do.

    ```bash
    terraform plan
    ```

2. **Apply Infrastructure Changes**: Apply the Terraform configurations to create the networking resources.

    ```bash
    terraform apply
    ```

3. **Destroy Infrastructure**: Tear down the created infrastructure when it's no longer needed.

    ```bash
    terraform destroy
    ```