#!/bin/bash

# Script to automatically fetch Azure AD credentials for Terraform
# This script will:
# 1. Get your Azure AD Tenant ID (required for all usage)
# 2. Optionally create a service principal for GitHub Actions (only if needed)

set -e

echo "🔐 Azure AD Credentials Setup Script"
echo "===================================="
echo ""
echo "This script helps you set up credentials for Terraform."
echo ""
echo "📌 What you need:"
echo "   - Tenant ID: Required for both local and GitHub Actions usage"
echo "   - Service Principal: Only needed if you want to use GitHub Actions"
echo "   - For local usage: Just run 'az login' and use the Tenant ID"
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

# Get Tenant ID
echo "📋 Fetching Azure AD Tenant ID..."
TENANT_ID=$(az account show --query tenantId -o tsv)
if [ -z "$TENANT_ID" ]; then
    echo "❌ Failed to get Tenant ID"
    exit 1
fi
echo "✅ Tenant ID: $TENANT_ID"
echo ""

# Get subscription info (for reference, not required for Entra ID)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "📋 Current Azure Subscription (for reference only):"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Subscription Name: $SUBSCRIPTION_NAME"
echo "   Note: Subscription is NOT required for Entra ID operations"
echo ""

# Ask if service principal is needed
echo "═══════════════════════════════════════════════════════════════"
echo "🔧 Service Principal Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Service Principal is ONLY needed if you want to use GitHub Actions."
echo "For local Terraform usage, you only need the Tenant ID (already fetched)."
echo ""
read -p "Do you need a Service Principal for GitHub Actions? (y/n) " -n 1 -r
echo
echo ""

SP_CREATED=false
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Service Principal name
    SP_NAME="github-actions-terraform-$(date +%s)"
    echo "🔧 Creating Azure AD Service Principal for GitHub Actions..."
    echo "   Service Principal Name: $SP_NAME"
    echo ""

    # Create service principal with Azure AD permissions
    echo "Creating service principal with 'User Administrator' role..."
    SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role "User Administrator" \
        --sdk-auth \
        --scopes "/" 2>&1)

    if [ $? -ne 0 ]; then
        echo "❌ Failed to create service principal"
        echo "$SP_OUTPUT"
        echo ""
        echo "You can still use Terraform locally with just the Tenant ID."
    else
        SP_CREATED=true
        echo "✅ Service Principal created successfully!"
        echo ""
    fi
else
    echo "⏭️  Skipping Service Principal creation"
    echo "   You can create one later if needed for GitHub Actions"
    echo ""
fi

# Output credentials
echo "═══════════════════════════════════════════════════════════════"
echo "📝 CREDENTIALS"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. AZURE_TENANT_ID (Required for all usage):"
echo "   $TENANT_ID"
echo ""

if [ "$SP_CREATED" = true ]; then
    echo "2. AZURE_CREDENTIALS (Only needed for GitHub Actions):"
    echo "   Copy the entire JSON below:"
    echo "$SP_OUTPUT"
    echo ""
    
    # Save to file (optional)
    read -p "💾 Save service principal credentials to a local file? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CREDS_FILE="azure-credentials-$(date +%Y%m%d-%H%M%S).json"
        echo "$SP_OUTPUT" > "$CREDS_FILE"
        echo "✅ Credentials saved to: $CREDS_FILE"
        echo "⚠️  WARNING: This file contains sensitive information!"
        echo "   - Do NOT commit this file to git"
        echo "   - Delete it after adding to GitHub Secrets"
        echo ""
    fi
else
    echo "ℹ️  Service Principal not created (not needed for local usage)"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    read -p "📝 Create terraform.tfvars file with tenant_id? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat > terraform.tfvars <<EOF
# Azure AD Tenant ID
tenant_id = "$TENANT_ID"
EOF
        echo "✅ Created terraform.tfvars"
        echo "⚠️  Remember: terraform.tfvars is in .gitignore and should NOT be committed"
        echo ""
    fi
fi

echo "═══════════════════════════════════════════════════════════════"
echo "✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "$SP_CREATED" = true ]; then
    echo "📋 For GitHub Actions:"
    echo "   1. Copy the AZURE_TENANT_ID and add it as a GitHub Secret"
    echo "   2. Copy the AZURE_CREDENTIALS JSON and add it as a GitHub Secret"
    echo "   3. Go to: https://github.com/YOUR_REPO/settings/secrets/actions"
    echo ""
fi

echo "📋 For Local Terraform Usage:"
echo "   1. Use the Tenant ID in your terraform.tfvars file"
echo "   2. Make sure you're logged in: az login"
echo "   3. Run: terraform init && terraform plan"
echo ""
echo "⚠️  Security Reminder:"
echo "   - Never commit credentials to git"
echo "   - Delete any credential files after use"
if [ "$SP_CREATED" = true ]; then
    echo "   - Rotate service principal credentials periodically"
fi
echo ""

