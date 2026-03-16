# AzureML Infra Foundation

A secure, enterprise-ready **Azure Machine Learning** baseline for deploying AML in private network environments. Use-case agnostic — focused on network isolation, identity, and governance — supporting both **Managed Virtual Network** and **Bring-Your-Own VNet** deployment models using a Terraform + Bicep hybrid approach.

This baseline is intended for **regulated, enterprise, and public-sector environments** where private endpoints, restricted egress, and controlled access to Azure ML Studio are required.

> **Managed VNet + Private Endpoints (Recommended)** — Managed VNet private endpoints are created when provisioning occurs (first compute creation or forced provisioning). This repo follows that pattern as the default secure baseline.

## Key Principles

- **Secure by default** — firewalled Storage/KV/ACR, private endpoints, managed VNet isolation
- **Use-case agnostic** — deploy the workspace, then bring any training code, pipeline, or model
- **Enterprise and public-sector ready** — supports VPN/ExpressRoute, private DNS, outbound egress controls, Entra ID join, managed identities
- **Extensible to Foundry** — the networking and RBAC patterns apply directly to Azure AI Foundry

## Deployment Options

Three Terraform configurations, from quickstart to fully secured:

| Option | Directory | Network Mode | Description |
|--------|-----------|--------------|-------------|
| **Quickstart** | `infra/terraform-quickstart/` | Public | Minimal workspace, no VNet or private endpoints. For learning and [Azure ML in a Day](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-azure-ml-in-a-day?view=azureml-api-2). |
| **Secure (Managed VNet)** | `infra/terraform/` | Private (Managed VNet) | Production-grade workspace with managed VNet isolation, firewalled backing services, private endpoints, Azure Bastion, and an Entra-joined Windows jumpbox. **Recommended baseline.** |
| **BYO VNet Foundation** | `infra/azure-ml-vnet/` | Custom (BYO VNet) | Standalone networking layer — VNet, delegated subnet, NSG service-tag rules, route table, managed identity. Compose with your own workspace deployment for hub-spoke or on-prem connectivity. |

## Architecture Overview

### Secure Baseline (Managed VNet)

See the full architecture diagram and detailed walkthrough in [infra/terraform/README.md](infra/terraform/README.md).

**How it works:**

1. All backing services (Storage, Key Vault, ACR) have public access disabled — accessible only via private endpoints.
2. AML workspace uses **Managed VNet isolation** (`AllowInternetOutbound`). Compute runs inside a Microsoft-managed VNet with automatic private endpoint creation on first provisioning.
3. Users connect through **Azure Bastion** → **Jumpbox VM** → private endpoints to the workspace and Azure ML Studio.
4. The jumpbox's **user-assigned managed identity** has `Contributor` (resource group) + `AzureML Data Scientist` (workspace), enabling `az login --identity` to bypass corporate Conditional Access restrictions on non-compliant devices.

### BYO VNet Foundation

For enterprises requiring custom network topologies (hub-spoke, on-prem connectivity via VPN/ExpressRoute, or custom egress controls), the `azure-ml-vnet` module deploys the networking foundation:

- VNet with delegated subnet (`Microsoft.MachineLearningServices/workspaces`)
- NSG with 12 rules covering all required AML service tags (inbound: AzureMachineLearning port 44224, BatchNodeManagement 29876-29877; outbound: AAD, AML, ARM, Storage, KV, ACR, AFD, Batch, MCR, Monitor)
- Route table (ready for UDR customization)
- User-assigned managed identity

Compose this with your own AML workspace Terraform, referencing the `subnet_id` output.

## Project Structure

```
azureml-infra-foundation/
├── README.md
├── infra/
│   ├── terraform/                  # Secure baseline (Managed VNet)
│   │   ├── main.tf                 # AML workspace + firewalled Storage/KV/ACR + private endpoints + DNS
│   │   ├── bastion_jumpbox.tf      # Azure Bastion (Standard SKU, tunneling enabled)
│   │   ├── jumpbox_vm.tf           # Windows Server 2022 jumpbox (Entra ID join, managed identity)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md               # Full deployment guide, access options, jumpbox setup
│   │
│   ├── terraform-quickstart/       # Public-access quickstart
│   │   ├── main.tf                 # AML workspace + compute instance/cluster (no networking)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md
│   │
│   └── azure-ml-vnet/              # BYO VNet networking foundation
│       ├── main.tf                 # VNet, subnet (delegated), NSG (12 service-tag rules), route table, MI
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── terraform.tfvars.example
│       └── README.md               # NSG rule reference, integration instructions
│
├── docs/                           # Additional guidance (coming soon)
├── examples/                       # Example configurations (coming soon)
├── azureml/                        # AML CLI v2 assets — environments, compute, etc. (coming soon)
└── notebooks/                      # Validation notebooks (coming soon)
```

## Prerequisites

### Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5.0 | Infrastructure deployment |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | Latest | Authentication and resource management |
| [Azure CLI ML extension](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli) | v2 | `az ml` commands for workspace management |

```bash
# Verify installations
terraform -version   # >= 1.5.0
az --version         # Latest
az extension add --name ml  # Install ML extension if not present
```

### Azure Permissions

| Scope | Role | Purpose |
|-------|------|---------|
| Subscription or Resource Group | **Contributor** | Create and manage resources |
| Subscription or Resource Group | **User Access Administrator** | Assign RBAC roles to managed identities |

> The Terraform configurations handle all downstream RBAC assignments (Storage Blob/File Contributor, AcrPush, Key Vault Admin, AzureML Data Scientist) automatically via `azurerm_role_assignment` resources.

## Installation and Setup

### Step 1: Clone the Repository and Install Dependencies

This project uses [uv](https://docs.astral.sh/uv/) for fast, cross-platform dependency management.

**Linux / macOS:**

```bash
# Clone the repository
git clone https://github.com/honestypugh2/azureml-infra-foundation.git
cd azureml-infra-foundation

# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies (creates .venv automatically)
uv sync

# Add environment to Jupyter kernelspec to use in Notebooks
uv run python -m ipykernel install --user --name .venv
```

**Windows (PowerShell):**

```powershell
# Clone the repository
git clone https://github.com/honestypugh2/azureml-infra-foundation.git
cd azureml-infra-foundation

# Install uv (if not already installed)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Install dependencies (creates .venv automatically)
uv sync

# Add environment to Jupyter kernelspec to use in Notebooks
uv run python -m ipykernel install --user --name .venv
```

### Step 2: Configure Azure Authentication

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify access
az account show --output table
```

> **On the jumpbox** (secure baseline deployment), use the pre-assigned managed identity instead:
>
> ```bash
> az login --identity
> ```
>
> This avoids corporate Conditional Access issues that block browser-based auth flows on non-Intune-compliant devices.

### Step 3: Deploy Infrastructure

Choose a deployment option and follow its README:

| Option | Guide |
|--------|-------|
| **Secure Baseline** (Recommended) | [infra/terraform/README.md](infra/terraform/README.md) |
| **Public Quickstart** (Learning only) | [infra/terraform-quickstart/README.md](infra/terraform-quickstart/README.md) |
| **BYO VNet Foundation** | [infra/azure-ml-vnet/README.md](infra/azure-ml-vnet/README.md) |

Each guide covers prerequisites, deployment steps, resource details, access options, RBAC assignments, networking configuration, validation, and cost considerations.

## Cleanup

```bash
# Destroy all resources for any deployment option
cd infra/<option-directory>
terraform destroy
```

## Extending to Azure AI Foundry

The networking patterns, private endpoints, and RBAC model in this repo apply directly to [Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-studio/). To extend:

1. Deploy the secure baseline workspace from `infra/terraform/`
2. Add AI Foundry hub/project resources referencing the same VNet and private DNS zones
3. Reuse the jumpbox and Bastion for access
4. Apply the same managed identity and RBAC patterns

## Roadmap

### Infrastructure
- [ ] Start with Terraform modules first, add Bicep equivalents after
- [ ] BYO Managed VNet — test and validate end-to-end
- [ ] Add AKS as a compute backend option
- [ ] CI/CD pipeline examples (GitHub Actions) for `terraform plan`/`apply`
- [ ] `AllowOnlyApprovedOutbound` FQDN rule examples
- [ ] Remote state backend configuration (Azure Storage)
- [ ] Policy-as-code (Azure Policy / OPA) for guardrails
- [ ] Example: attaching BYO VNet module to a workspace deployment

### Foundry
- [ ] Azure AI Foundry hub/project Terraform module

### Use Cases
- [ ] Time series forecasting — based on [aml-v2-lstm-ts-forecasting-demo](https://github.com/honestypugh2/aml-v2-lstm-ts-forecasting-demo)
- [ ] Manufacturing
- [ ] Healthcare

### Validation
- [ ] Validation scripts and notebooks for post-deployment checks


## References

- [Azure ML Enterprise Security](https://learn.microsoft.com/en-us/azure/machine-learning/concept-enterprise-security?view=azureml-api-2)
- [Secure Azure ML Workspace (Tutorial)](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-create-secure-workspace?view=azureml-api-2)
- [Managed VNet Isolation](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-managed-network?view=azureml-api-2)
- [Configure Private Endpoints](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-private-link?view=azureml-api-2)
- [Azure ML CLI v2 Reference](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli?view=azureml-api-2)
- [Azure AI Foundry Documentation](https://learn.microsoft.com/en-us/azure/ai-studio/)

## License

See [LICENSE](LICENSE) for details.

---
