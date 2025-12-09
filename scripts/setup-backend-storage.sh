#!/bin/bash

# Script to create Azure Storage Account for Terraform state backend
# This script will:
# 1. Create a resource group for Terraform state
# 2. Create an Azure Storage Account
# 3. Create a container for state files
# 4. Configure access and security
# 5. Output backend configuration

set -e

echo "🗄️  Terraform State Backend Setup Script"
echo "=========================================="
echo ""
echo "This script creates an Azure Storage Account for storing Terraform state files."
echo "This provides secure, centralized state management with locking and versioning."
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo "⚠️  You are not logged in to Azure CLI"
    echo "   Please run: az login"
    exit 1
fi

echo "✅ Azure CLI is installed and you are logged in"
echo ""

# Get subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "📋 Current Azure Subscription:"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Subscription Name: $SUBSCRIPTION_NAME"
echo ""

# Configuration variables
read -p "Enter resource group name (default: terraform-state-rg): " RG_NAME
RG_NAME=${RG_NAME:-terraform-state-rg}

read -p "Enter storage account name (must be globally unique, 3-24 chars, lowercase): " STORAGE_NAME
if [ -z "$STORAGE_NAME" ]; then
    STORAGE_NAME="tfstate$(date +%s | tail -c 9)"
    echo "   Generated name: $STORAGE_NAME"
fi

read -p "Enter location (default: eastus): " LOCATION
LOCATION=${LOCATION:-eastus}

read -p "Enter container name (default: tfstate): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-tfstate}

read -p "Enter state file key/name (default: entra-infrastructure.tfstate): " STATE_KEY
STATE_KEY=${STATE_KEY:-entra-infrastructure.tfstate}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📋 Configuration Summary"
echo "═══════════════════════════════════════════════════════════════"
echo "   Resource Group: $RG_NAME"
echo "   Storage Account: $STORAGE_NAME"
echo "   Location: $LOCATION"
echo "   Container: $CONTAINER_NAME"
echo "   State Key: $STATE_KEY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Create resource group
echo "📦 Creating resource group: $RG_NAME..."
az group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ Resource group created"
else
    echo "❌ Failed to create resource group"
    exit 1
fi

# Create storage account
echo "💾 Creating storage account: $STORAGE_NAME..."
az storage account create \
    --resource-group "$RG_NAME" \
    --name "$STORAGE_NAME" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --location "$LOCATION" \
    --allow-blob-public-access false \
    --min-tls-version TLS1_2 \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ Storage account created"
else
    echo "❌ Failed to create storage account"
    echo "   Note: Storage account name must be globally unique"
    exit 1
fi

# Get storage account key
echo "🔑 Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RG_NAME" \
    --account-name "$STORAGE_NAME" \
    --query "[0].value" -o tsv)

# Create container
echo "📁 Creating container: $CONTAINER_NAME..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ Container created"
else
    echo "❌ Failed to create container"
    exit 1
fi

# Enable versioning and soft delete (for state file protection)
echo "🔒 Enabling blob versioning and soft delete..."
az storage account blob-service-properties update \
    --account-name "$STORAGE_NAME" \
    --resource-group "$RG_NAME" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 7 \
    --output none

echo "✅ Versioning and soft delete enabled"
echo ""

# Generate backend configuration
echo "═══════════════════════════════════════════════════════════════"
echo "📝 Backend Configuration"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Create a file named 'backend.tf' with the following content:"
echo ""
cat <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RG_NAME"
    storage_account_name  = "$STORAGE_NAME"
    container_name        = "$CONTAINER_NAME"
    key                   = "$STATE_KEY"
  }
}
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Save backend config to file
read -p "💾 Save backend configuration to backend.tf? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat > backend.tf <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RG_NAME"
    storage_account_name  = "$STORAGE_NAME"
    container_name        = "$CONTAINER_NAME"
    key                   = "$STATE_KEY"
  }
}
EOF
    echo "✅ Backend configuration saved to backend.tf"
    echo "⚠️  Remember: backend.tf should NOT be committed if it contains sensitive info"
    echo ""
fi

# Save storage account info (without key)
read -p "💾 Save storage account info to a file? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    INFO_FILE="backend-storage-info-$(date +%Y%m%d-%H%M%S).txt"
    cat > "$INFO_FILE" <<EOF
Terraform Backend Storage Information
====================================
Resource Group: $RG_NAME
Storage Account: $STORAGE_NAME
Container: $CONTAINER_NAME
State Key: $STATE_KEY
Location: $LOCATION
Subscription ID: $SUBSCRIPTION_ID

⚠️  WARNING: This file does NOT contain the storage account key.
   The key is required for Terraform to access the backend.
   Store it securely (e.g., in Azure Key Vault or GitHub Secrets).
EOF
    echo "✅ Storage info saved to: $INFO_FILE"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo "✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📋 Next Steps:"
echo "1. Add backend.tf to your Terraform configuration"
echo "2. Run 'terraform init' to initialize the backend"
echo "3. If migrating from local state, Terraform will ask to migrate"
echo ""
echo "🔐 Security Recommendations:"
echo "- Store storage account key in Azure Key Vault"
echo "- Use managed identity for GitHub Actions"
echo "- Enable blob versioning (already enabled)"
echo "- Enable soft delete (already enabled)"
echo "- Use different state keys for different tenants/environments"
echo ""
echo "📚 For multiple tenants, use different keys:"
echo "   - tenant1: key = \"tenant1/entra-infrastructure.tfstate\""
echo "   - tenant2: key = \"tenant2/entra-infrastructure.tfstate\""
echo "   - prod: key = \"prod/entra-infrastructure.tfstate\""
echo ""

