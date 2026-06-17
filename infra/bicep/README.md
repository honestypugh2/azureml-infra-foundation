# Bicep Modular AML Infrastructure (US-1.1)

This directory contains the US-1.1 starter implementation for a modular Azure ML infrastructure baseline in Bicep.

The implementation is **AVM-aligned**:

- module boundaries and parameter naming follow Azure Verified Modules conventions
- AML workspace contract is modeled from `avm/res/machine-learning-services/workspace`
- secure defaults are applied (`publicNetworkAccess: Disabled`, datastore auth via identity, deny-by-default data-plane networking)

## Files

- `main.bicep` — composition entrypoint
- `main.bicepparam` — sample parameter file for a dev deployment
- `modules/backing-services.bicep` — Log Analytics, App Insights, Storage, Key Vault, optional ACR
- `modules/aml-workspace.bicep` — AML workspace module (AVM-inspired contract)

## Deploy

```powershell
az deployment group create `
  --resource-group <resource-group-name> `
  --template-file infra\bicep\main.bicep `
  --parameters infra\bicep\main.bicepparam
```

## Notes

- Storage account and container registry names must be globally unique.
- This is the initial modular baseline; follow-up sub-issues can layer in BYO VNet, private endpoints, DNS zones, and RBAC role assignments using additional modules.
