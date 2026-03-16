# Azure ML Quickstart (Public Access)

Minimal Terraform deployment for Azure Machine Learning with **public network access** enabled.
No VNets, private endpoints, or jumpbox VMs — designed to get you running the
[Azure ML in a Day](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-azure-ml-in-a-day?view=azureml-api-2) tutorial quickly.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Resource Group                                 │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │  Azure ML Workspace (public access)      │   │
│  │  ├── Compute Instance (notebooks/dev)    │   │
│  │  └── Compute Cluster  (training jobs)    │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Storage  │  │ Key Vault│  │ Container    │  │
│  │ Account  │  │          │  │ Registry     │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
│                                                 │
│  ┌──────────────┐  ┌──────────────────────┐    │
│  │ Log Analytics│  │ Application Insights │    │
│  └──────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Resources Created

| Resource | Purpose |
|---|---|
| Resource Group | Container for all resources |
| Storage Account | Default AML datastore |
| Key Vault | Secrets & credentials |
| Container Registry (Basic) | Training environment images |
| Log Analytics Workspace | Monitoring backend |
| Application Insights | AML telemetry |
| AML Workspace | Machine learning workspace (public) |
| Compute Instance | Interactive notebooks & development |
| Compute Cluster | Scalable training jobs (0–2 nodes) |

## Prerequisites

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (logged in)
- An Azure subscription with Contributor access

## Quick Start

```bash
# 1. Navigate to this directory
cd infra/terraform-quickstart

# 2. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Log in to Azure
az login

# 4. Initialize and deploy
terraform init
terraform plan
terraform apply
```

After deployment completes, open Azure ML Studio:

```bash
terraform output aml_studio_url
```

Or go directly to [https://ml.azure.com](https://ml.azure.com) and select your workspace.

## Running the LSTM Training Pipeline

Once the workspace is up, submit a training job from your local machine:

```bash
# From the repo root
cd ../..
pip install -r requirements.in

# Submit the training job to Azure ML
python src/azure_ml_training/submit_training_job.py
```

Or use the notebooks in the `notebooks/` directory from the Compute Instance in ML Studio.

## Cost Control

- The compute cluster scales to **0 nodes** when idle (after 2 minutes)
- The compute instance runs continuously while started — **stop it** in ML Studio when not in use
- ACR uses **Basic** SKU (cheapest tier)
- Storage uses **Standard LRS** (cheapest replication)

## Cleanup

```bash
terraform destroy
```

## Comparison with Secure Deployment

For a production-ready deployment with VNet isolation, private endpoints, and managed network,
see [`../terraform/`](../terraform/).

| Feature | Quickstart (this) | Secure (`../terraform/`) |
|---|---|---|
| Network access | Public | Private (managed VNet) |
| Private endpoints | None | Workspace + all backing services |
| VNet / Bastion / Jumpbox | None | Yes |
| ACR SKU | Basic | Premium (PE required) |
| Cost | Lower | Higher |
| Use case | Dev / learning | Production |
