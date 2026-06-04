
locals {
  tenzir_platform_domain_without_protocol = replace(var.tenzir_platform_domain, "/^(https?|wss?):\\/\\//", "")
  tenzir_platform_api_endpoint_without_protocol = replace(var.tenzir_platform_api_endpoint, "/^(https?|wss?):\\/\\//", "")
  tenzir_platform_nodes_endpoint_without_protocol = replace(var.tenzir_platform_control_endpoint, "/^(https?|wss?):\\/\\//", "")
}

resource "google_compute_global_address" "platform_ip" {
  name = "platform-ingress-ip"
}

resource "kubernetes_manifest" "app_managed_certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "app-managed-certificate"
      namespace = "default"
    }
    spec = {
      domains = [local.tenzir_platform_domain_without_protocol]
    }
  }
}

resource "kubernetes_manifest" "platform_managed_certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "platform-managed-certificate"
      namespace = "default"
    }
    spec = {
      domains = [local.tenzir_platform_api_endpoint_without_protocol]
    }
  }
}


resource "kubernetes_manifest" "gateway_managed_certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "gateway-managed-certificate"
      namespace = "default"
    }
    spec = {
      domains = [local.tenzir_platform_nodes_endpoint_without_protocol]
    }
  }
}

resource "kubernetes_ingress_v1" "platform_ingress_iap" {
  metadata {
    name      = "platform-ingress-iap"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.platform_ip.name
      "networking.gke.io/managed-certificates"     = join(",", [
        kubernetes_manifest.app_managed_certificate.manifest.metadata.name,
        kubernetes_manifest.platform_managed_certificate.manifest.metadata.name,
        kubernetes_manifest.gateway_managed_certificate.manifest.metadata.name,
      ])
    }
  }
  spec {
    rule {
      host = local.tenzir_platform_domain_without_protocol
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.app_service.metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
    rule {
      host = local.tenzir_platform_api_endpoint_without_protocol
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.platform_service.metadata[0].name
              port {
                number = 5000
              }
            }
          }
        }
      }
    }
    rule {
      host = local.tenzir_platform_nodes_endpoint_without_protocol
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.websocket_gateway_service.metadata[0].name
              port {
                number = 5001
              }
            }
          }
        }
      }
    }
  }

  depends_on = [ kubernetes_manifest.app_backend_config ]
}

resource "google_compute_firewall" "allow_gke_traffic" {
  name        = "allow-iap-traffic-ingress"
  network     = module.bootstrap.network_id
  description = "Allow inbound traffic to GKE cluster from specified CIDRs"

  direction = "INGRESS"

  # The inbound IP ranges for Google IAP, as provided in their
  # documentation.
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  allow {
    protocol = "tcp"
  }
}


