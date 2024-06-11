terraform {
  required_version = ">=1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }

}

locals {
  name = var.instance == "default" ? var.name : "${var.name}-${var.instance}"
  selector_labels = {
    "app.kubernetes.io/name"     = var.name
    "app.kubernetes.io/instance" = var.instance
  }
  common_labels = {
    "app.kubernetes.io/version"    = var.image_tag
    "app.kubernetes.io/managed-by" = "terraform"
  }
  labels = merge(local.common_labels, var.extra_labels, local.selector_labels)
  built_in_users = {
    kibana_system          = {}
    logstash_system        = {}
    beats_system           = {}
    apm_system             = {}
    remote_monitoring_user = {}
  }
}
