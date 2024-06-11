resource "kubernetes_stateful_set_v1" "elasticsearch" {

  metadata {
    name        = local.name
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels
  }

  spec {
    pod_management_policy = var.pod_management_policy
    replicas              = var.replicas

    selector {
      match_labels = local.selector_labels
    }

    service_name = kubernetes_service_v1.elasticsearch.metadata.0.name

    template {

      metadata {
        labels = merge(local.labels, { "app.kubernetes.io/config-hash" = md5(kubernetes_config_map_v1.elasticsearch_yaml.data["elasticsearch.yml"]) })
      }

      spec {

        service_account_name            = kubernetes_service_account_v1.elasticsearch.metadata.0.name
        automount_service_account_token = true

        security_context {
          run_as_user  = var.user_id
          run_as_group = var.group_id
          fs_group     = var.group_id
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [var.name]
                }
                match_expressions {
                  key      = "app.kubernetes.io/instance"
                  operator = "In"
                  values   = [var.instance]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        init_container {
          name              = "keystore-init"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = var.image_tag == "latest" ? "Always" : "IfNotPresent"
          command = [
            "bash",
            "-ec"
          ]
          args = [join("; ", [
            "IFS=': '",
            "while read key value",
            "do echo $${value//\\\"} | ./bin/elasticsearch-keystore add -f -x $${key//\\\"}",
            "done < /tmp/elasticsearch.keystore.tmpl"
          ])]

          volume_mount {
            name       = "keystore"
            mount_path = "/tmp/elasticsearch.keystore.tmpl"
            sub_path   = "elasticsearch.keystore"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "${var.elasticsearch_home}/config"
          }

        }

        container {
          name              = "elasticsearch"
          image             = "${var.image_name}:${var.image_tag}"
          image_pull_policy = var.image_tag == "latest" ? "Always" : "IfNotPresent"
          command = [
            "./bin/elasticsearch"
          ]
          args = []

          dynamic "env" {
            for_each = merge(var.extra_env, {})
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            name           = "http"
            protocol       = "TCP"
            container_port = local.elasticsearch_default_config["http.port"]
          }

          port {
            name           = "transport"
            protocol       = "TCP"
            container_port = local.elasticsearch_default_config["transport.port"]
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          volume_mount {
            name       = "data"
            mount_path = var.storage_path
          }

          volume_mount {
            name       = "config"
            mount_path = "${var.elasticsearch_home}/config/elasticsearch.yml"
            sub_path   = "elasticsearch.yml"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "${var.elasticsearch_home}/config/roles.yml"
            sub_path   = "roles.yml"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "${var.elasticsearch_home}/config/elasticsearch.keystore"
            sub_path   = "elasticsearch.keystore"
            read_only  = true
          }

          dynamic "volume_mount" {
            for_each = var.tls_secret_name != null ? { pki = {} } : {}
            content {
              name       = "pki"
              mount_path = "${var.elasticsearch_home}/config/pki"
              read_only  = true
            }
          }

          readiness_probe {
            period_seconds        = 10
            initial_delay_seconds = 60
            success_threshold     = 1
            failure_threshold     = 3
            timeout_seconds       = 10

            http_get {
              scheme = var.tls_secret_name != null ? "HTTPS" : "HTTP"
              path   = "/_cluster/health"
              port   = "http"
            }
          }
        }

        dynamic "volume" {
          for_each = var.storage_class == null ? { data = {} } : {}
          content {
            name = volume.key
            empty_dir {}
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.elasticsearch_yaml.metadata.0.name
          }
        }

        volume {
          name = "keystore"
          secret {
            secret_name  = kubernetes_secret_v1.elasticsearch_keystore.metadata.0.name
            default_mode = "0600"
            optional     = false
          }
        }

        volume {
          name = "tmp"
          empty_dir {
            medium     = "Memory"
            size_limit = "1Mi"
          }
        }

        dynamic "volume" {
          for_each = var.tls_secret_name != null ? { pki = {} } : {}
          content {
            name = "pki"
            secret {
              secret_name  = var.tls_secret_name
              default_mode = "0600"
              optional     = false
            }
          }
        }

        dynamic "toleration" {
          for_each = {
            for toleration in var.tolerations : toleration["key"] => toleration
          }
          content {
            key      = toleration.key
            operator = toleration.value["operator"]
            value    = toleration.value["value"]
            effect   = toleration.value["effect"]
          }
        }

      }

    }

    dynamic "volume_claim_template" {

      for_each = var.storage_class != null ? { data = {} } : {}

      content {
        metadata {
          name = volume_claim_template.key
        }
        spec {

          storage_class_name = var.storage_class
          access_modes       = ["ReadWriteOnce"]

          resources {
            requests = {
              storage = var.storage_size
            }
          }

        }
      }

    }

  }
  wait_for_rollout = var.wait_for_rollout
}

resource "random_password" "elasticsearch_bootstrap_password" {
  length  = 24
  upper   = true
  lower   = true
  numeric = true
  special = false
}
