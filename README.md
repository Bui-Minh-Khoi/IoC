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
4. **Azure subscription** (optional, for some resources)

## Setup

1. **Install Terraform providers:**
   ```bash
   terraform init
   ```

2. **Configure your Azure credentials:**
   ```bash
   az login
   az account show  # Get your tenant ID and subscription ID
   ```

3. **Create terraform.tfvars file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars` and add your:
   - `tenant_id`: Your Azure AD Tenant ID
   - `subscription_id`: Your Azure Subscription ID (optional)

4. **Update user information:**
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

### Required GitHub Secrets

Configure the following secrets in your GitHub repository settings:

- `AZURE_TENANT_ID` - Your Azure AD Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Your Azure Subscription ID
- `AZURE_CREDENTIALS` - Azure service principal credentials (JSON format)

To create Azure credentials for GitHub Actions:

```bash
az ad sp create-for-rbac --name "github-actions-terraform" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

Copy the JSON output and add it as the `AZURE_CREDENTIALS` secret.

### Manual Workflow Trigger

You can manually trigger the apply workflow from the GitHub Actions tab:
1. Go to Actions → Terraform Apply
2. Click "Run workflow"
3. Select the branch and click "Run workflow"

## File Structure

- `main.tf` - Main Terraform configuration for Entra ID resources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `users.json` - User information file (name@domain, password, role)
- `terraform.tfvars.example` - Example variables file
- `.gitignore` - Git ignore rules for Terraform files
- `.github/workflows/` - GitHub Actions workflow files

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
