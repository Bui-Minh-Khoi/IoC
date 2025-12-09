# Terraform State Management Guide

## Overview

This document explains how to manage Terraform state files for Entra ID infrastructure, especially when managing multiple tenants.

## Why Remote State?

Storing Terraform state in a public GitHub repository is **not recommended** because:

1. **Security Risk**: State files contain sensitive information
2. **No Locking**: Multiple users can modify infrastructure simultaneously
3. **No Versioning**: Difficult to track changes and rollback
4. **No Backup**: Risk of data loss

## Recommended Solution: Azure Storage Account

Azure Storage Account provides:

- ✅ **Secure Storage**: Encrypted at rest with access control
- ✅ **State Locking**: Prevents concurrent modifications
- ✅ **Versioning**: Automatic version history
- ✅ **Soft Delete**: Recovery of deleted state files
- ✅ **Cost Effective**: Low cost for small state files

## Setup Instructions

### Quick Setup

Run the automated setup script:

```bash
./scripts/setup-backend-storage.sh
```

This will:
1. Create a resource group
2. Create a storage account
3. Create a container for state files
4. Enable versioning and soft delete
5. Generate backend configuration

### Manual Setup

1. **Create Storage Account**:
   ```bash
   az group create --name terraform-state-rg --location eastus
   az storage account create \
     --resource-group terraform-state-rg \
     --name terraformstate \
     --sku Standard_LRS \
     --kind StorageV2
   ```

2. **Create Container**:
   ```bash
   az storage container create \
     --name tfstate \
     --account-name terraformstate
   ```

3. **Configure Backend**:
   Create `backend.tf`:
   ```hcl
   terraform {
     backend "azurerm" {
       resource_group_name  = "terraform-state-rg"
       storage_account_name = "terraformstate"
       container_name       = "tfstate"
       key                  = "entra-infrastructure.tfstate"
     }
   }
   ```

4. **Initialize Backend**:
   ```bash
   terraform init
   ```

## Multi-Tenant State Management

### Strategy

Use different state keys for different tenants/environments:

```
tfstate/
├── tenant1/
│   └── entra-infrastructure.tfstate
├── tenant2/
│   └── entra-infrastructure.tfstate
├── prod/
│   └── entra-infrastructure.tfstate
└── staging/
    └── entra-infrastructure.tfstate
```

### Implementation

1. **Create separate backend configurations**:
   - `backend-tenant1.tf`
   - `backend-tenant2.tf`
   - `backend-prod.tf`

2. **Use workspaces or separate directories**:
   ```bash
   # Option 1: Use Terraform workspaces
   terraform workspace new tenant1
   terraform workspace select tenant1
   
   # Option 2: Use separate directories
   mkdir -p tenants/tenant1
   cd tenants/tenant1
   # Copy terraform files and configure backend
   ```

3. **Use different state keys**:
   ```hcl
   # backend-tenant1.tf
   terraform {
     backend "azurerm" {
       key = "tenant1/entra-infrastructure.tfstate"
     }
   }
   ```

## Security Best Practices

1. **Storage Account Access**:
   - Use Azure Key Vault for storing access keys
   - Use managed identity for GitHub Actions
   - Enable private endpoints for production

2. **State File Protection**:
   - Enable blob versioning (automatic backups)
   - Enable soft delete (recovery capability)
   - Use RBAC to restrict access

3. **Git Repository**:
   - Never commit `backend.tf` if it contains access keys
   - Use GitHub Secrets for CI/CD
   - Use `.gitignore` to exclude sensitive files

## Migration from Local State

If you have existing local state:

1. **Backup current state**:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Configure backend**:
   Create `backend.tf` with your storage account details

3. **Initialize and migrate**:
   ```bash
   terraform init
   # Terraform will detect existing state and ask to migrate
   # Type "yes" to migrate
   ```

4. **Verify**:
   ```bash
   terraform plan
   # Should show "No changes" if migration was successful
   ```

## GitHub Actions Integration

For GitHub Actions to use remote state:

1. **Add Storage Account Key to Secrets**:
   - Go to GitHub repository settings
   - Add secret: `AZURE_STORAGE_ACCOUNT_KEY`

2. **Update Workflow**:
   The backend configuration in `backend.tf` will be used automatically.
   Ensure the storage account key is available via:
   - Environment variable
   - Azure Key Vault
   - Managed Identity (recommended)

## Troubleshooting

### "Backend initialization required"
Run `terraform init` to initialize the backend.

### "Error acquiring state lock"
Another process is using the state. Wait or force unlock:
```bash
terraform force-unlock <lock-id>
```

### "Storage account not found"
Verify:
- Storage account name is correct
- Resource group name is correct
- You have access to the storage account

## Alternative Backend Options

1. **Terraform Cloud**: Managed state with UI and collaboration
2. **AWS S3 + DynamoDB**: For AWS environments
3. **Google Cloud Storage**: For GCP environments
4. **HashiCorp Consul**: For on-premises solutions

## Cost Estimation

Azure Storage Account costs (approximate):
- Storage: $0.0184 per GB/month
- Transactions: $0.004 per 10,000 operations
- For typical Terraform usage: < $1/month

## References

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/index.html)
- [Azure Storage Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)

