# IoC - Infrastructure as Code

This repository contains Terraform configuration for initializing an Entra ID (Azure AD) infrastructure.

## Overview

This Terraform configuration creates:
- Azure AD users from a JSON file
- Azure AD security groups for roles
- User-to-role group assignments

## Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** >= 1.0 installed
3. **Azure AD permissions** to create users and groups
4. **Azure AD Tenant ID** (subscription NOT required for Entra ID resources)
5. **Azure Storage Account** (optional, for remote state backend - recommended for production)

## Setup

1. **Install Terraform providers:**
   ```bash
   terraform init
   ```

2. **Configure your Azure credentials:**

   **Option A: Automated Setup (Recommended)**
   ```bash
   # Run the setup script to automatically fetch credentials
   ./scripts/setup-azure-credentials.sh
   ```
   This script will:
   - Get your Azure AD Tenant ID
   - Create a service principal for GitHub Actions
   - Generate credentials in the required format
   - Optionally create `terraform.tfvars` file

   **Option B: Manual Setup**
   ```bash
   az login
   az account show  # Get your tenant ID (subscription ID not needed)
   ```

3. **Create terraform.tfvars file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars` and add your:
   - `tenant_id`: Your Azure AD Tenant ID (required)
   
   **Note:** Azure Subscription ID is NOT required for managing Entra ID (Azure AD) users and groups. Only the Tenant ID is needed.

4. **Configure Terraform Backend (Recommended for Production):**
   
   **Option A: Automated Setup**
   ```bash
   # Create Azure Storage Account for state backend
   ./scripts/setup-backend-storage.sh
   ```
   This script will:
   - Create an Azure Storage Account
   - Create a container for state files
   - Generate backend configuration
   - Enable versioning and soft delete for state protection
   
   **Option B: Manual Setup**
   ```bash
   # Copy the example backend configuration
   cp backend.tf.example backend.tf
   # Edit backend.tf with your storage account details
   ```
   
   **Why use remote state?**
   - Secure, encrypted state storage
   - State locking prevents concurrent modifications
   - Version history and backup capabilities
   - Support for multiple tenants/environments
   - Better than storing state in public GitHub repositories

5. **Update user information:**
   Edit `users.json` to add/modify users with their:
   - `name`: User principal name (email format)
   - `password`: Initial password (users will be forced to change on first login)
   - `role`: Role name (will create/assign to a security group)
   - `displayName`, `givenName`, `surname`: User details

## Usage

1. **Review the plan:**
   ```bash
   terraform plan
   ```

2. **Apply the configuration:**
   ```bash
   terraform apply
   ```

3. **Destroy resources (if needed):**
   ```bash
   terraform destroy
   ```

## GitHub Actions Automation

This repository includes GitHub Actions workflows for automated Terraform operations:

### Workflows

1. **Terraform Plan** (`.github/workflows/terraform-plan.yml`)
   - Runs on pull requests to `main` branch
   - Performs `terraform fmt`, `terraform init`, `terraform validate`, and `terraform plan`
   - Comments the plan output on the PR
   - Uploads the plan as an artifact

2. **Terraform Apply** (`.github/workflows/terraform-apply.yml`)
   - Runs on pushes to `main` branch or manual trigger
   - Performs `terraform plan` and `terraform apply`
   - Automatically applies changes when code is merged to main

### Required GitHub Secrets (Only for GitHub Actions)

**Note:** Service principal is ONLY needed if you want to use GitHub Actions. For local Terraform usage, you only need the Tenant ID and `az login`.

Configure the following secrets in your GitHub repository settings:

- `AZURE_TENANT_ID` - Your Azure AD Tenant ID (required)
- `AZURE_CREDENTIALS` - Azure AD service principal credentials (JSON format) - **Only needed for GitHub Actions**

**Quick Setup (Recommended):**
```bash
# Use the automated setup script
# It will ask if you need a service principal for GitHub Actions
./scripts/setup-azure-credentials.sh
```

**Manual Setup (GitHub Actions only):**
```bash
# Create a service principal with Azure AD permissions
az ad sp create-for-rbac --name "github-actions-terraform" \
  --role "User Administrator" \
  --sdk-auth
```

Or for more granular permissions, you can assign specific Azure AD roles:

```bash
# Create service principal
SP_APP_ID=$(az ad sp create-for-rbac --name "github-actions-terraform" --sdk-auth --query appId -o tsv)

# Assign Azure AD roles (example: User Administrator)
az role assignment create \
  --assignee $SP_APP_ID \
  --role "User Administrator" \
  --scope "/"
```

Copy the JSON output and add it as the `AZURE_CREDENTIALS` secret.

### Manual Workflow Trigger

You can manually trigger the apply workflow from the GitHub Actions tab:
1. Go to Actions → Terraform Apply
2. Click "Run workflow"
3. Select the branch and click "Run workflow"

## Terraform State Management

### Remote State Backend

This repository supports Azure Storage Account as a remote state backend, which provides:

- **Security**: Encrypted state storage with access control
- **State Locking**: Prevents concurrent modifications
- **Versioning**: Automatic version history of state files
- **Multi-Tenant Support**: Use different state keys for different tenants

### Multi-Tenant State Management

For managing multiple tenants, use different state keys:

```
tenant1/entra-infrastructure.tfstate
tenant2/entra-infrastructure.tfstate
prod/entra-infrastructure.tfstate
staging/entra-infrastructure.tfstate
```

This allows you to:
- Manage multiple Azure AD tenants from a single repository
- Isolate state files per tenant/environment
- Apply changes independently to each tenant

### Backend Configuration

The backend configuration is stored in `backend.tf` (not committed to git if it contains sensitive info).

Example structure:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "tenant1/entra-infrastructure.tfstate"
  }
}
```

## File Structure

- `main.tf` - Main Terraform configuration for Entra ID resources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `backend.tf.example` - Example backend configuration for remote state
- `users.json` - User information file (name@domain, password, role)
- `terraform.tfvars.example` - Example variables file
- `.gitignore` - Git ignore rules for Terraform files
- `.github/workflows/` - GitHub Actions workflow files
- `scripts/setup-azure-credentials.sh` - Automated script to fetch Azure AD credentials
- `scripts/setup-backend-storage.sh` - Automated script to create Azure Storage Account for state backend

## Security Notes

⚠️ **Important:**
- The `users.json` file contains sensitive information (passwords)
- Consider using Azure Key Vault or Terraform Cloud for password management in production
- Never commit `terraform.tfvars` or actual passwords to version control
- Users will be forced to change their password on first login (`force_password_change = true`)

## Outputs

After applying, Terraform will output:
- User IDs mapped to their principal names
- User display names
- Group IDs for each role
- User-to-role group memberships
