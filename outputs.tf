output "name" {
  value = var.name
}

output "namespace" {
  value = var.namespace
}

output "pod_selector" {
  value = local.selector_labels
}

output "load_balanced_url" {
  description = ""
  value       = "${var.tls_secret_name != null ? "https" : "http"}://${kubernetes_service_v1.elasticsearch.metadata.0.name}.${kubernetes_service_v1.elasticsearch.metadata.0.namespace}:9200"
}

output "hosts" {
  description = ""
  value = [
    for index in range(0, var.replicas) : "${var.tls_secret_name != null ? "https" : "http"}://${local.name}-${index}.${local.name}.${var.namespace}:9200"
  ]
}

output "service_account_name" {
  value = kubernetes_service_account_v1.elasticsearch.metadata.0.name
}

output "service_name" {
  value = kubernetes_service_v1.elasticsearch.metadata.0.name
}

output "root_credentials_secret_name" {
  value = kubernetes_secret_v1.elasticsearch_root_credentials.metadata.0.name
}

output "admin_username" {
  value     = "elastic"
  sensitive = true
}

output "admin_password" {
  value     = random_password.elasticsearch_root_password.result
  sensitive = true
}

output "elasticsearch_version" {
  value = var.image_tag
}

output "elastic_built_in_users" {
  value = { for k, v in var.elasticsearch_built_in_users :
    k => merge(v, { password = random_password.elasticsearch_built_in_user[k].result })
  }
  sensitive = true
}
