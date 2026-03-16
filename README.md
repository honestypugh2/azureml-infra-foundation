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

Follow the [Quick Start](#quick-start) section below to deploy your chosen option.

## Quick Start

### Option A: Secure Baseline (Recommended)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set subscription_id, resource names, admin_password
```

```bash
az login
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

After deployment, connect to the workspace through Azure Bastion:

```bash
# Option 1: Browser-based RDP via Azure Portal
#   Portal → Bastion → Connect to jumpbox VM

# Option 2: CLI tunnel (local RDP client)
az network bastion tunnel \
  --name "$(terraform output -raw bastion_name)" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --target-resource-id "$(terraform output -raw jumpbox_vm_id)" \
  --resource-port 3389 --port 33389

# Option 3: CLI-only SSH tunnel
az network bastion tunnel \
  --name "$(terraform output -raw bastion_name)" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --target-resource-id "$(terraform output -raw jumpbox_vm_id)" \
  --resource-port 22 --port 2222
```

On the jumpbox, authenticate with the pre-assigned managed identity:

```bash
az login --identity
az ml workspace show \
  --name "$(terraform output -raw aml_workspace_name)" \
  --resource-group "$(terraform output -raw resource_group_name)"
```

### Option B: Public Quickstart (Learning Only)

```bash
cd infra/terraform-quickstart
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

az login
terraform init
terraform apply
```

Open the workspace directly:

```bash
echo "$(terraform output -raw aml_studio_url)"
```

### Option C: BYO VNet Foundation

```bash
cd infra/azure-ml-vnet
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

az login
terraform init
terraform apply
```

Use the outputs (`subnet_id`, `nsg_id`, `user_assigned_identity_id`) when creating your AML workspace with BYO VNet integration.

## Resources Deployed

### Secure Baseline (`infra/terraform/`)

| Resource | Configuration | Purpose |
|----------|---------------|---------|
| Resource Group | — | Container for all resources |
| Virtual Network | 10.30.0.0/16 | Jumpbox + Bastion networking |
| NAT Gateway | Standard | Deterministic outbound IP for jumpbox subnet |
| Azure Bastion | Standard SKU, tunneling enabled | Secure access to jumpbox (no public IP on VM) |
| Windows VM (jumpbox) | Standard_D4s_v3, Entra ID joined | Access point for AML Studio and CLI |
| User-Assigned MI | Contributor + AzureML Data Scientist | Jumpbox authentication |
| Storage Account | Firewall: Deny, shared keys disabled | AML default datastore |
| Key Vault | Firewall: Deny | Secrets and certificates |
| Container Registry | Premium, public access disabled | Custom environment images |
| Application Insights | + Log Analytics | Workspace telemetry |
| AML Workspace | Managed VNet (`AllowInternetOutbound`) | Machine learning platform |
| AML Compute Cluster | Standard_DS3_v2, 0–4 nodes | Training compute |
| Private Endpoints (6) | Workspace, blob, file, vault, ACR, notebooks | Zero public-internet access |
| Private DNS Zones (8) | api.azureml.ms, notebooks, blob, file, vault, ACR, etc. | Name resolution for private endpoints |

### Public Quickstart (`infra/terraform-quickstart/`)

| Resource | Configuration | Purpose |
|----------|---------------|---------|
| Resource Group | — | Container |
| Storage Account | Public access, shared keys via Azure AD | AML datastore |
| Key Vault | Standard, public | Secrets |
| Container Registry | Basic, public | Images |
| Application Insights | + Log Analytics | Telemetry |
| AML Workspace | Public, no managed VNet | Machine learning platform |
| Compute Instance | Standard_DS3_v2 | Interactive development |
| Compute Cluster | Standard_DS3_v2, 0–2 nodes | Training jobs |

### BYO VNet Foundation (`infra/azure-ml-vnet/`)

| Resource | Configuration | Purpose |
|----------|---------------|---------|
| Resource Group | — | Container |
| Virtual Network | 10.1.0.0/16 | AML networking |
| Subnet | 10.1.0.0/24, delegated to ML Services | Compute hosting |
| Network Security Group | 12 rules (2 inbound, 10 outbound) | AML service-tag traffic |
| Route Table | Empty (ready for UDRs) | Custom routing |
| User-Assigned MI | — | AML workspace/compute identity |

## Networking Deep Dive

### Managed VNet Isolation Modes

| Mode | Outbound Access | Use Case |
|------|----------------|----------|
| `AllowInternetOutbound` | Compute can reach the internet + all private endpoints created automatically | Default — suitable for most workloads needing pip/conda access |
| `AllowOnlyApprovedOutbound` | Compute can only reach explicitly approved destinations | Strict egress control — add FQDN outbound rules for required endpoints |

Change the isolation mode via the `aml_isolation_mode` variable in `infra/terraform/variables.tf`.

### Managed VNet Provisioning

Private endpoints inside the managed VNet are **not** created at workspace deployment time. They are created when:

1. **First compute resource** is created (compute instance or cluster), or
2. **Manual provisioning** is triggered via `az ml workspace provision-network`

```bash
# Force provisioning without creating compute
az ml workspace provision-network \
  --name <workspace-name> \
  --resource-group <resource-group> \
  --include-spark
```

### Enterprise Network Integration

| Scenario | Approach |
|----------|----------|
| **VPN/ExpressRoute** | Use `azure-ml-vnet` BYO VNet module; peer with hub VNet or attach VPN gateway |
| **Hub-spoke topology** | Deploy `azure-ml-vnet` as a spoke; peer to hub; route through firewall via UDRs |
| **Custom DNS** | Point VNet DNS to your resolver; add conditional forwarders for `privatelink.*` zones |
| **Outbound firewall (NVA)** | Use `AllowOnlyApprovedOutbound`; add UDRs in route table to force traffic through NVA |
| **Image build behind firewall** | Enable ACR tasks with private endpoints, or use pre-built images from private ACR |

## RBAC Reference

### Automated by Terraform

The IaC configurations assign these roles automatically:

| Principal | Role | Scope | Config |
|-----------|------|-------|--------|
| AML Workspace MI | Storage Blob Data Contributor | Storage Account | `terraform/` |
| AML Workspace MI | Storage File Data Privileged Contributor | Storage Account | `terraform/` |
| AML Workspace MI | AcrPush | Container Registry | `terraform/` |
| AML Workspace MI | Key Vault Administrator | Key Vault | `terraform/` |
| Jumpbox MI | Contributor | Resource Group | `terraform/` |
| Jumpbox MI | AzureML Data Scientist | AML Workspace | `terraform/` |
| Deploying user | Virtual Machine Administrator Login | Jumpbox VM | `terraform/` |
| Deploying user | Contributor | AML Workspace | `terraform/` |
| Deploying user | Storage Blob Data Contributor | Storage Account | `terraform-quickstart/` |
| Deploying user | Storage File Data Privileged Contributor | Storage Account | `terraform-quickstart/` |

### Additional Roles for Teams

| Role | Scope | Who |
|------|-------|-----|
| AzureML Data Scientist | AML Workspace | Data scientists submitting jobs |
| AzureML Compute Operator | AML Workspace | Users managing compute resources |
| Reader | Resource Group | Auditors and observers |

## Validation

After deployment, verify the workspace is operational:

```bash
# Verify workspace
az ml workspace show --name <workspace> --resource-group <rg> --output table

# List compute (should show your cluster)
az ml compute list --workspace-name <workspace> --resource-group <rg> --output table

# Submit a smoke-test job (from jumpbox for secure deployment)
az ml job create \
  --workspace-name <workspace> \
  --resource-group <rg> \
  --file - <<'EOF'
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
command: echo "Hello from Azure ML"
environment: azureml://registries/azureml/environments/sklearn-1.5/labels/latest
compute: azureml:cpu-cluster
EOF
```

## Cost Considerations

| Component | Secure Baseline | Quickstart |
|-----------|----------------|------------|
| AML Workspace | Free tier | Free tier |
| Compute Cluster | Pay per use (scales to 0) | Pay per use (scales to 0) |
| Compute Instance | — | Runs continuously until stopped |
| Jumpbox VM (D4s_v3) | ~$140/mo (running) | — |
| Azure Bastion (Standard) | ~$140/mo | — |
| NAT Gateway | ~$32/mo + data | — |
| ACR Premium | ~$50/mo | ACR Basic ~$5/mo |
| Storage, KV, App Insights | Usage-based | Usage-based |

> **Tip:** Stop the jumpbox VM and Bastion when not in use. Compute clusters auto-scale to zero nodes when idle.

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

- [ ] CI/CD pipeline examples (GitHub Actions) for `terraform plan`/`apply`
- [ ] Validation scripts and notebooks for post-deployment checks
- [ ] `AllowOnlyApprovedOutbound` FQDN rule examples
- [ ] Azure AI Foundry hub/project Terraform module
- [ ] Remote state backend configuration (Azure Storage)
- [ ] Policy-as-code (Azure Policy / OPA) for guardrails
- [ ] Example: attaching BYO VNet module to a workspace deployment

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
