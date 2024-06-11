resource "kubernetes_service_account_v1" "elasticsearch" {
  metadata {
    name        = local.name
    namespace   = var.namespace
    labels      = local.labels
    annotations = var.service_account_annotations
  }

  dynamic "image_pull_secret" {
    for_each = { for image_pull_secret in var.image_pull_secrets : image_pull_secret => {} }
    content {
      name = image_pull_secret.key
    }
  }

}
