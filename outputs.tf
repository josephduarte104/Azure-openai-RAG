# Output important information
output "ai_search_admin_key" {
  value = azurerm_search_service.ai_search.primary_key
  sensitive = true
}

output "ai_service_endpoint" {
  value = azurerm_cognitive_account.ai_services.endpoint
}

output "ai_service_key" {
  value = azurerm_cognitive_account.ai_services.primary_access_key
  sensitive = true
}

output "ai_service_id" {
  value = azurerm_cognitive_account.ai_services.id
}