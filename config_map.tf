resource "kubernetes_config_map_v1" "elasticsearch_yaml" {
  metadata {
    name        = local.name
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels
  }
  data = {
    "elasticsearch.yml" = yamlencode(merge(
      local.elasticsearch_default_config,
      local.elasticsearch_security_config,
      local.elasticsearch_cluster_config,
      local.elasticsearch_extra_config
    ))
    "roles.yml" = yamlencode({
      health_check = {
        cluster = ["cluster:monitor/health"]
      }
    })
  }
}

resource "kubernetes_secret_v1" "elasticsearch_keystore" {

  metadata {
    name      = "${local.name}-keystore"
    namespace = var.namespace
  }

  data = {
    "elasticsearch.keystore" = yamlencode(merge(var.elasticsearch_secure_settings, {
      "bootstrap.password" = random_password.elasticsearch_bootstrap_password.result
    }))
  }

  type = "Opaque"
}

locals {
  elasticsearch_default_config = {
    "cluster.name"            = local.name
    "node.name"               = "$${HOSTNAME}"
    "path.data"               = "${var.storage_path}/data"
    "network.host"            = "_site_"
    "network.publish_host"    = "$${HOSTNAME}.${kubernetes_service_v1.elasticsearch.metadata.0.name}.${var.namespace}"
    "discovery.type"          = var.replicas == 1 ? "single-node" : "multi-node"
    "xpack.security.enabled"  = false
    "http.port"               = 9200
    "http.compression"        = true
    "http.max_content_length" = "1024mb"
    "transport.port"          = 9300
  }
  elasticsearch_security_config = var.tls_secret_name != null ? {
    "xpack.security.enabled"                               = true
    "xpack.security.http.ssl.enabled"                      = true
    "xpack.security.http.ssl.key"                          = "${var.elasticsearch_home}/config/pki/tls.key"
    "xpack.security.http.ssl.certificate"                  = "${var.elasticsearch_home}/config/pki/tls.crt"
    "xpack.security.http.ssl.certificate_authorities"      = "${var.elasticsearch_home}/config/pki/ca.crt"
    "xpack.security.transport.ssl.enabled"                 = true
    "xpack.security.transport.ssl.key"                     = "${var.elasticsearch_home}/config/pki/tls.key"
    "xpack.security.transport.ssl.certificate"             = "${var.elasticsearch_home}/config/pki/tls.crt"
    "xpack.security.transport.ssl.certificate_authorities" = "${var.elasticsearch_home}/config/pki/ca.crt"
    "xpack.security.transport.ssl.verification_mode"       = "full"
    "xpack.security.authc.anonymous.roles"                 = ["health_check"]
  } : tomap({})
  elasticsearch_cluster_config = var.replicas > 1 ? {
    "discovery.seed_hosts"         = [for index in range(0, var.replicas) : "${local.name}-${index}.${local.name}"]
    "cluster.initial_master_nodes" = [for index in range(0, var.replicas) : "${local.name}-${index}"]
  } : tomap({})
  elasticsearch_extra_config = var.elasticsearch_extra_config
}
