resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-data-pvc"
    namespace = "default"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    # Default on GKE is 'standard-rwo', but the deployment below defaults to 'standard'
    # so we have to explicitly match it here
    storage_class_name = "standard"
  }
}

resource "kubernetes_deployment" "postgres_deployment" {
  metadata {
    name      = "postgres"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
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
          name  = "postgres"
          image = "postgres:14.5"

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
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "TENZIR_PLATFORM_POSTGRES_USER"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tenzir_platform_secrets.metadata[0].name
                key  = "TENZIR_PLATFORM_POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name  = "POSTGRES_DB"
            value = var.tenzir_platform_postgres_db
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata/"
          }
          port {
            container_port = 5432
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data/"
          }
          liveness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
          readiness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U postgres"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres_service" {
  metadata {
    name      = "postgres-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}