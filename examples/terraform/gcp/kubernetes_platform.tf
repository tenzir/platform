resource "kubernetes_deployment" "platform_deployment" {
  metadata {
    name      = "platform"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "platform"
      }
    }
    template {
      metadata {
        labels = {
          app = "platform"
        }
      }
      spec {
        security_context {
          run_as_non_root = false
          supplemental_groups = []
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        toleration {
          effect = "NoSchedule"
          key    = "kubernetes.io/arch"
          operator = "Equal"
          value  = "amd64"
        }

        container {
          name  = "platform"
          image = "${module.bootstrap.registry_baseurl}/platform:${var.tenzir_platform_version}"
          command = ["python", "-m", "tenant_manager.rest.server.local"]

          readiness_probe {
            http_get {
              path = "/user/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = "/user/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          # Define a security context with default values to
          # avoid seeing the same changes on every `terraform apply`.

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = false
            run_as_non_root            = false

            capabilities {
              add  = []
              drop = ["NET_RAW"]
            }
          }

          env {
            name  = "BASE_PATH"
            value = ""
          }
          env {
            name  = "GATEWAY_WS_ENDPOINT"
            value = var.tenzir_platform_control_endpoint
          }
          env {
            name  = "GATEWAY_HTTP_ENDPOINT"
            value = "http://websocket-gateway-service:5001"
          }
          env {
            name  = "TENANT_MANAGER_DISABLE_LOCAL_DEMO_NODES"
            value = "true"
          }
          env {
            name  = "TENZIR_DEMO_NODE_IMAGE"
            value = var.tenzir_platform_demo_node_image
          }
          env {
            name = "TENANT_MANAGER_APP_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "TENZIR_PLATFORM_INTERNAL_APP_API_KEY"
              }
            }
          }
          env {
            name = "TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY"
              }
            }
          }
          env {
            name = "TENANT_MANAGER_AUTH__TRUSTED_AUDIENCES"
            value = "{\"issuer\":\"https://cloud.google.com/iap\",\"audiences\":[\"/projects/1040868523377/global/backendServices/1046898633656365971\"]}"
          }
          env {
            name = "TENANT_MANAGER_AUTH__ADMIN_FUNCTIONS"
            value = "[]"
          }
          env {
            name  = "STORE__TYPE"
            value = var.tenzir_platform_store_type
          }
          env {
            name = "STORE__POSTGRES_URI"
            value = "postgresql://${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_USER}:${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_PASSWORD}@postgres-service:5432/${var.tenzir_platform_postgres_db}"
          }
          env {
            name  = "TENANT_MANAGER_SIDEPATH_BUCKET_NAME"
            value = var.tenzir_platform_internal_bucket_name
          }
          env {
            name  = "BLOB_STORAGE__ENDPOINT_URL"
            value = "http://seaweed-service:8333"
          }
          env {
            name  = "BLOB_STORAGE__PUBLIC_ENDPOINT_URL"
            value = var.tenzir_platform_blobs_endpoint
          }
          env {
            name = "BLOB_STORAGE__ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "BLOB_STORAGE_ACCESS_KEY_ID"
              }
            }
          }
          env {
            name = "BLOB_STORAGE__SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "BLOB_STORAGE_SECRET_ACCESS_KEY"
              }
            }
          }
          port {
            container_port = 5000
          }
        }
      }
    }
  }
}


resource "kubernetes_manifest" "platform_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "platform-backend-config"
      namespace = "default"
    }
    spec = {
      iap = {
        enabled        = true
        oauthclientCredentials = {
          secretName = kubernetes_secret.iap_oauth_secret.metadata[0].name
        }
      }

      timeoutSec = 300
      connectionDraining = {
        drainingTimeoutSec = 300
      }
    }
  }
}

resource "kubernetes_service" "platform_service" {
  metadata {
    name      = "platform-service"
    namespace = "default"
    annotations = {
      "cloud.google.com/backend-config" = jsonencode({
          "default" = "platform-backend-config"
      })
    }
  }
  spec {
    selector = {
      app = "platform"
    }
    port {
      port        = 5000
      target_port = 5000
    }
    type = "NodePort"
  }
}