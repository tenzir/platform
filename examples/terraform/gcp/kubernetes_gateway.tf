resource "kubernetes_deployment" "websocket_gateway_deployment" {
  metadata {
    name      = "websocket-gateway"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "websocket-gateway"
      }
    }
    template {
      metadata {
        labels = {
          app = "websocket-gateway"
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
          name  = "websocket-gateway"
          image = "${module.bootstrap.registry_baseurl}/platform:${var.tenzir_platform_version}"

          readiness_probe {
            http_get {
              path = "/health"
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
              path = "/health"
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

          command = ["python", "-m", "tenant_manager.ws.server.local"] # Corrected command for Python module
          env {
            name  = "BASE_PATH"
            value = ""
          }
          env {
            name  = "TENZIR_PROXY_TIMEOUT"
            value = "60"
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
            name  = "STORE__TYPE"
            value = var.tenzir_platform_store_type
          }
          env {
            name = "STORE__POSTGRES_URI"
            value = "postgresql://${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_USER}:${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_PASSWORD}@postgres-service:5432/${var.tenzir_platform_postgres_db}"
          }
          port {
            container_port = 5001
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "gateway_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "gateway-backend-config"
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

resource "kubernetes_service" "websocket_gateway_service" {
  metadata {
    name      = "websocket-gateway-service"
    namespace = "default"
    annotations = {
      "cloud.google.com/backend-config" = jsonencode({
          "default" = kubernetes_manifest.gateway_backend_config.manifest.metadata.name
      })
    }
  }
  spec {
    selector = {
      app = "websocket-gateway"
    }
    port {
      port        = 5001
      target_port = 5000
    }
    type = "NodePort"
  }
}