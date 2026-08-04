# Resource: Kubernetes Deployment for App

resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "app"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app"
      }
    }
    template {
      metadata {
        labels = {
          app = "app"
        }
      }
      spec {
        security_context {
          run_as_non_root = false # Or true, depending on what kubectl shows
          supplemental_groups = [] # Or the actual values if present
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
          name  = "app"
          image = "${module.bootstrap.registry_baseurl}/app:${var.tenzir_platform_version}"

          # need to define a readiness probe to overwrite the default '/' path
          # for GKE ingress health checks
          readiness_probe {
            http_get {
              path = "/login"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = "/login"
              port = 3000
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
            name  = "AUTH_TRUST_HOST"
            value = "true"
          }
          env {
            name  = "PUBLIC_ENABLE_HIGHLIGHT"
            value = "false"
          }
          env {
            name  = "PRIVATE_JWT_FROM_HEADER"
            value = "true"
          }
          env {
            name  = "ORIGIN"
            value = var.tenzir_platform_domain
          }
          env {
            name  = "PRIVATE_OIDC_PROVIDER_NAME"
            value = "tenzir"
          }
          env {
            name  = "PRIVATE_OIDC_PROVIDER_CLIENT_ID"
            value = "tenzir-app"
          }
          env {
            name = "PRIVATE_OIDC_PROVIDER_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "PRIVATE_OIDC_PROVIDER_CLIENT_SECRET"
              }
            }
          }
          env {
            name  = "PRIVATE_OIDC_PROVIDER_ISSUER_URL"
            value = "http://platform-service:5000/oidc"
          }
          env {
            name  = "PUBLIC_OIDC_PROVIDER_ID"
            value = "tenzir"
          }
          env {
            name  = "PUBLIC_USE_INTERNAL_WS_PROXY"
            value = "true"
          }
          env {
            name  = "PUBLIC_WEBSOCKET_GATEWAY_ENDPOINT"
            value = "http://websocket-gateway-service:5001"
          }
          env {
            name  = "PRIVATE_USER_ENDPOINT"
            value = "http://platform-service:5000/user"
          }
          env {
            name  = "PRIVATE_WEBAPP_ENDPOINT"
            value = "http://platform-service:5000/webapp"
          }
          env {
            name = "PRIVATE_WEBAPP_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "TENZIR_PLATFORM_INTERNAL_APP_API_KEY"
              }
            }
          }
          env {
            name = "AUTH_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "AUTH_SECRET"
              }
            }
          }
          env {
            name  = "PUBLIC_DISABLE_DEMO_NODE_AND_TOUR"
            # value = tostring(var.tenzir_platform_disable_local_demo_nodes)
            value = "true"
          }
          env {
            name = "PRIVATE_DRIZZLE_DATABASE_URL"
            value = "postgres://${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_USER}:${kubernetes_secret.tenzir_platform_secrets.data.TENZIR_PLATFORM_POSTGRES_PASSWORD}@postgres-service:5432/${var.tenzir_platform_postgres_db}"
          }
          port {
            container_port = 3000
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "app_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "app-backend-config"
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

# Resource: Kubernetes Service for App
resource "kubernetes_service" "app_service" {
  metadata {
    name      = "app-service"
    namespace = "default"
    annotations = {
      "cloud.google.com/backend-config" = jsonencode({
          "default" = "app-backend-config"
      })
    }
  }
  spec {
    selector = {
      app = "app"
    }
    port {
      port        = 3000
      target_port = 3000
    }
    type = "NodePort"
  }
}
