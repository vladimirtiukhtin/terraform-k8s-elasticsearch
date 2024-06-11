resource "kubernetes_job_v1" "elasticsearch_root_user_set_up" {

  metadata {
    name        = "${local.name}-root-user-setup"
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels
  }

  spec {

    template {

      metadata {
        // labels = local.labels ToDo: service also selects job pod as it is labeled the same. It also spoils affinity
      }

      spec {
        container {
          name              = "root-user-set-up"
          image             = "curlimages/curl:8.1.2"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/sh", "-ec"]
          args = var.tls_secret_name != null ? [join(" ", [
            "curl",
            "--request POST",
            "--cacert /usr/local/share/ca-certificates/ca.crt",
            "--fail-early",
            "--fail-with-body",
            "--no-progress-meter",
            "--header 'Content-Type: application/json'",
            "--user elastic:${random_password.elasticsearch_bootstrap_password.result}",
            "--data '{\"password\":\"'$${ELASTIC_PASSWORD}'\"}'",
            "https://${kubernetes_service_v1.elasticsearch.metadata.0.name}:9200/_security/user/elastic/_password",
            ])] : [
            "echo \"No password set, security disabled\""
          ]

          env {
            name = "ELASTIC_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.elasticsearch_root_credentials.metadata.0.name
                key  = "password"
              }
            }
          }

          dynamic "volume_mount" {
            for_each = var.tls_secret_name != null ? { pki = {} } : {}
            content {
              name       = "pki"
              mount_path = "/usr/local/share/ca-certificates/ca.crt"
              sub_path   = "ca.crt"
              read_only  = true
            }
          }

        }

        dynamic "volume" {
          for_each = var.tls_secret_name != null ? { pki = {} } : {}
          content {
            name = "pki"
            secret {
              secret_name = var.tls_secret_name
            }
          }
        }

        restart_policy = "OnFailure"

      }
    }
    backoff_limit = 10
  }

  depends_on = [
    kubernetes_stateful_set_v1.elasticsearch
  ]

  wait_for_completion = true

  timeouts {
    create = "10m"
    update = "10m"
  }

}

resource "random_password" "elasticsearch_root_password" {
  length  = 64
  upper   = true
  lower   = true
  numeric = true
  special = false
}

resource "kubernetes_secret_v1" "elasticsearch_root_credentials" {

  metadata {
    name      = "${local.name}-root-credentials"
    namespace = var.namespace
  }

  data = {
    username = "elastic"
    password = random_password.elasticsearch_root_password.result
  }

  type = "kubernetes.io/basic-auth"
}

resource "kubernetes_job_v1" "elasticsearch_built_in_user_set_up" {

  metadata {
    name        = "${local.name}-built-in-user-set-up"
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels
  }

  spec {

    template {

      metadata {
        // labels = local.labels ToDo: service also selects job pod as it is labeled the same. It also spoils affinity
      }

      spec {
        dynamic "container" {
          for_each = var.tls_secret_name != null ? {
            for k, v in var.elasticsearch_built_in_users : k => {
              cmd = join(";", [
                join(" ", ["curl",
                  "--request POST",
                  "--cacert /usr/local/share/ca-certificates/ca.crt",
                  "--fail-early",
                  "--fail-with-body",
                  "--no-progress-meter",
                  "--header 'Content-Type: application/json'",
                  "--user elastic:$${ELASTIC_PASSWORD}",
                  "--data '{\"password\":\"'$${USER_PASSWORD}'\"}'",
                  "https://${kubernetes_service_v1.elasticsearch.metadata.0.name}:9200/_security/user/${k}/_password"
                ]),
                join(" ", ["curl",
                  "--request PUT",
                  "--cacert /usr/local/share/ca-certificates/ca.crt",
                  "--fail-early",
                  "--fail-with-body",
                  "--no-progress-meter",
                  "--header 'Content-Type: application/json'",
                  "--user elastic:$${ELASTIC_PASSWORD}",
                  "https://${kubernetes_service_v1.elasticsearch.metadata.0.name}:9200/_security/user/${k}/${v.enabled == true ? "_enable" : "_disable"}"
                ])
              ])
            }
            } : {
            no_security = {
              cmd = "echo \"No password set, security disabled\""
            }
          }

          content {
            name              = "${replace(container.key, "_", "-")}-user-set-up"
            image             = "curlimages/curl:8.1.2"
            image_pull_policy = "IfNotPresent"
            command           = ["/bin/sh", "-ec"]
            args              = [container.value["cmd"]]

            env {
              name = "ELASTIC_PASSWORD"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.elasticsearch_root_credentials.metadata.0.name
                  key  = "password"
                }
              }
            }

            dynamic "env" {
              for_each = container.key == "no_security" ? {} : { "${container.key}" = {} }
              content {
                name = "USER_PASSWORD"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.elasticsearch_built_in_user_credentials[container.key].metadata.0.name
                    key  = "password"
                  }
                }
              }
            }

            dynamic "volume_mount" {
              for_each = var.tls_secret_name != null ? { pki = {} } : {}
              content {
                name       = "pki"
                mount_path = "/usr/local/share/ca-certificates/ca.crt"
                sub_path   = "ca.crt"
                read_only  = true
              }
            }

          }
        }

        dynamic "volume" {
          for_each = var.tls_secret_name != null ? { pki = {} } : {}
          content {
            name = "pki"
            secret {
              secret_name = var.tls_secret_name
            }
          }
        }

        restart_policy = "Never"

      }
    }
    backoff_limit = 3
  }

  wait_for_completion = true

  depends_on = [
    kubernetes_job_v1.elasticsearch_root_user_set_up
  ]

  timeouts {
    create = "10m"
    update = "10m"
  }

}

resource "random_password" "elasticsearch_built_in_user" {
  for_each = var.elasticsearch_built_in_users
  length   = 64
  upper    = true
  lower    = true
  numeric  = true
  special  = true
}

resource "kubernetes_secret_v1" "elasticsearch_built_in_user_credentials" {

  for_each = var.elasticsearch_built_in_users

  metadata {
    name      = "${local.name}-${replace(each.key, "_", "-")}-credentials"
    namespace = var.namespace
  }

  data = {
    username = each.key
    password = random_password.elasticsearch_built_in_user[each.key].result
  }

  type = "kubernetes.io/basic-auth"
}
