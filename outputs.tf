output "user_ids" {
  description = "Map of user principal names to their object IDs"
  value = {
    for user_key, user in azuread_user.users : user_key => user.id
  }
  sensitive = false
}

output "user_display_names" {
  description = "Map of user principal names to their display names"
  value = {
    for user_key, user in azuread_user.users : user_key => user.display_name
  }
  sensitive = false
}

output "user_passwords" {
  description = "Map of user principal names to their generated passwords (SENSITIVE - do not share)"
  value = {
    for user_key, password in random_password.user_passwords : user_key => password.result
  }
  sensitive = true
}

output "group_ids" {
  description = "Map of role group names to their object IDs"
  value = {
    for group_key, group in azuread_group.role_groups : group_key => group.id
  }
  sensitive = false
}

output "group_memberships" {
  description = "Map showing which users are in which groups"
  value = {
    for pair_key, pair in azuread_group_member.user_role_assignments : pair_key => {
      user = azuread_user.users[pair.user_key].user_principal_name
      role = azuread_group.role_groups[pair.role].display_name
    }
  }
  sensitive = false
}

