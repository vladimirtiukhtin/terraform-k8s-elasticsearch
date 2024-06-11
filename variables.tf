variable "name" {
  description = "Common application name"
  type        = string
  default     = "elasticsearch"
}

variable "instance" {
  description = "Common instance name"
  type        = string
  default     = "default"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "replicas" {
  description = "Number of cluster nodes. Recommended value is the one which equals number of kubernetes nodes"
  type        = number
  default     = 3
}

variable "user_id" {
  description = "Unix UID to apply to persistent volume"
  type        = number
  default     = 1000
}

variable "group_id" {
  description = "Unix GID to apply to persistent volume"
  type        = number
  default     = 1000
}

variable "image_name" {
  description = "Container image name including registry address"
  type        = string
  default     = "docker.elastic.co/elasticsearch/elasticsearch"
}

variable "image_tag" {
  description = "Container image tag (version)"
  type        = string
  default     = "8.8.2"
}

variable "image_pull_secrets" {
  description = "List of existing image pull secrets to attach to a service account"
  type        = list(string)
  default     = []
}

variable "pod_management_policy" {
  description = "OrderedReady or Parallel"
  type        = string
  default     = "Parallel"
}

variable "elasticsearch_home" {
  description = ""
  type        = string
  default     = "/usr/share/elasticsearch"
}

variable "elasticsearch_secure_settings" {
  description = "A map of secure settings to add to Elasticsearch keystore, \"bootstrap.password\" included by default"
  type        = map(string)
  default     = {}
}

variable "elasticsearch_extra_config" {
  description = "Any extra options to add to elasticsearch.yml"
  type        = any
  default     = null
}

variable "elasticsearch_built_in_users" {
  description = ""
  type = map(object({
    enabled = optional(bool, false)
  }))
  default = {
    kibana_system = {
      enabled = true
    }
    logstash_system = {
      enabled = false
    }
    beats_system = {
      enabled = false
    }
    apm_system = {
      enabled = false
    }
    remote_monitoring_user = {
      enabled = false
    }
  }
}

variable "tls_secret_name" {
  description = ""
  type        = string
  default     = null
}

variable "cpu_request" {
  description = ""
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = ""
  type        = string
  default     = "2Gi"
}

variable "cpu_limit" {
  description = ""
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = ""
  type        = string
  default     = "4Gi"
}

variable "service_account_annotations" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "statefulset_annotations" {
  description = "Annotations to apply to StatefulSet"
  type        = map(string)
  default     = null
}

variable "service_annotations" {
  description = ""
  type        = map(any)
  default     = {}
}

variable "storage_class" {
  description = ""
  type        = string
  default     = null
}

variable "storage_path" {
  description = ""
  type        = string
  default     = "/var/lib/elasticsearch"
}

variable "storage_size" {
  description = ""
  type        = string
  default     = "16Gi"
}

variable "node_affinity" {
  description = ""
  type = object({
    kind  = string
    label = string
    value = string
  })
  default = null
}

variable "tolerations" {
  description = "List of node taints a pod tolerates"
  type = list(object({
    key      = optional(string)
    operator = optional(string, null)
    value    = optional(string, null)
    effect   = optional(string, null)
  }))
  default = []
}

variable "extra_env" {
  description = "Any extra environment variables to apply to elastic statefulset"
  type        = map(string)
  default     = {}
}

variable "extra_labels" {
  description = "Any extra labels to apply to kubernetes resources"
  type        = map(string)
  default     = {}
}

variable "wait_for_rollout" {
  description = "Whether to wait kubernetes readiness prove to succeed"
  type        = bool
  default     = true
}
