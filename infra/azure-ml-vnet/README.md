# Azure ML – BYO VNet Foundation (Terraform)

Standalone networking foundation for Azure Machine Learning compute when using a
**Bring Your Own VNet** (BYO VNet) topology. This module provisions a VNet,
delegated subnet, NSG rules, route table, and managed identity that can be
referenced by an Azure ML workspace.

This module implements the required NSG service-tag rules documented in
[Workspace Managed Virtual Network Isolation – List of required rules](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-managed-network?view=azureml-api-2#list-of-required-rules).

## Resources created

| Resource | Purpose |
|---|---|
| Resource Group | Container for all networking resources |
| Virtual Network | Core network for Azure ML workloads |
| Subnet (delegated) | `Microsoft.MachineLearningServices/workspaces` delegation |
| Network Security Group | Required service-tag rules (see table below) |
| Route Table | Placeholder – add UDRs for forced tunneling as needed |
| User-Assigned Managed Identity | Attach to AML workspace and compute clusters |

## NSG rules (per Microsoft docs)

### Inbound

| Rule | Service Tag | Ports | Purpose |
|---|---|---|---|
| AllowAzureMachineLearningInbound | `AzureMachineLearning` | 44224 | Compute instance/cluster management |
| AllowBatchNodeManagementInbound | `BatchNodeManagement` | 29876-29877 | Azure Batch back-end for compute |

### Outbound

| Rule | Service Tag | Ports | Purpose |
|---|---|---|---|
| AllowAzureActiveDirectoryOutbound | `AzureActiveDirectory` | 443 | Microsoft Entra ID authentication |
| AllowAzureMachineLearningOutbound | `AzureMachineLearning` | 443, 5831, 8787, 18881 | AML services, compute management, notebooks |
| AllowAzureResourceManagerOutbound | `AzureResourceManager` | 443 | ARM operations |
| AllowStorageOutbound | `Storage` | 443 | Default datastore access |
| AllowKeyVaultOutbound | `AzureKeyVault` | 443 | Secrets and keys |
| AllowContainerRegistryOutbound | `AzureContainerRegistry` | 443 | ACR access |
| AllowAzureFrontDoorOutbound | `AzureFrontDoor.FirstParty` | 443 | Microsoft-provided Docker images |
| AllowBatchNodeManagementOutbound | `BatchNodeManagement` | 443 | Azure Batch back-end |
| AllowMicrosoftContainerRegistryOutbound | `MicrosoftContainerRegistry` | 443 | Microsoft-provided Docker images |
| AllowAzureMonitorOutbound | `AzureMonitor` | 443 | Monitoring and metrics |

## Prerequisites

* [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
* An Azure subscription with Contributor (or Owner) access
* Azure CLI authenticated (`az login`)

## Quick start

```bash
cd infra/azure-ml-vnet

terraform init
terraform plan \
  -var="subscription_id=<YOUR_SUBSCRIPTION_ID>"

terraform apply \
  -var="subscription_id=<YOUR_SUBSCRIPTION_ID>"
```

Or copy and edit the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars, then:
terraform init && terraform apply
```

## Outputs

After `terraform apply`, the following values are exported:

* `resource_group_name` / `resource_group_id`
* `vnet_id` / `vnet_name`
* `subnet_id` / `subnet_name`
* `nsg_id`
* `route_table_id`
* `user_assigned_identity_id` / `_principal_id` / `_client_id`

Use `subnet_id` when creating or attaching an Azure ML workspace to this VNet.

## Relationship to `infra/terraform`

| Directory | Purpose |
|---|---|
| `infra/terraform/` | **Full secure workspace** — AML workspace + all dependencies + managed VNet + jumpbox/Bastion |
| `infra/azure-ml-vnet/` | **BYO VNet foundation** — standalone networking with NSG rules and managed identity |

## Next steps

1. **Create an Azure ML workspace** that references the `subnet_id` output for
   VNet integration.
2. **Tighten NSG rules** – the defaults allow the minimum service tags required
   by Azure ML; review and restrict further for production.
3. **Add Private Endpoints** for Storage, Key Vault, and Container Registry if
   you need full private networking.

## References

* [Tutorial: Create a secure workspace with a managed virtual network](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-create-secure-workspace?view=azureml-api-2)
* [Workspace Managed Virtual Network Isolation](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-managed-network?view=azureml-api-2)
* [azureml-examples: workspace-managed-network.ipynb](https://github.com/Azure/azureml-examples/blob/main/sdk/python/resources/workspace/workspace-managed-network.ipynb)
