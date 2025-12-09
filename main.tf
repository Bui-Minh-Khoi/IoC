terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

# Read user data from JSON file
locals {
  users_data = jsondecode(file("${path.module}/users.json"))
  users      = local.users_data.users
}

# Create Azure AD users
resource "azuread_user" "users" {
  for_each = { for user in local.users : user.name => user }

  user_principal_name = each.value.name
  display_name        = each.value.displayName
  given_name          = each.value.givenName
  surname             = each.value.surname
  password            = each.value.password
  force_password_change = true
  account_enabled     = true
}

# Create Azure AD groups for roles
resource "azuread_group" "role_groups" {
  for_each = toset([for user in local.users : user.role])

  display_name     = each.value
  security_enabled = true
  mail_enabled     = false
}

# Assign users to their respective role groups
resource "azuread_group_member" "user_role_assignments" {
  for_each = {
    for user in local.users : "${user.name}-${user.role}" => {
      user_key = user.name
      role     = user.role
    }
  }

  group_object_id  = azuread_group.role_groups[each.value.role].id
  member_object_id = azuread_user.users[each.value.user_key].id
}

