resource "kubernetes_service_v1" "elasticsearch" {

  metadata {
    name        = local.name
    namespace   = var.namespace
    annotations = var.service_annotations
    labels      = local.labels
  }

  spec {
    type       = "ClusterIP"
    cluster_ip = "None"

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 9200
      target_port = "http"
    }

    port {
      name        = "transport"
      protocol    = "TCP"
      port        = 9300
      target_port = "transport"
    }

    publish_not_ready_addresses = true
    selector                    = local.selector_labels
  }

}
