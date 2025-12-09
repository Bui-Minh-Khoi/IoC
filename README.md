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

## File Structure

- `main.tf` - Main Terraform configuration for Entra ID resources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `users.json` - User information file (name@domain, password, role)
- `terraform.tfvars.example` - Example variables file
- `.gitignore` - Git ignore rules for Terraform files

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
