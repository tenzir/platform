module "bootstrap" {
  source = "./modules/bootstrap"
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.platform_gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.platform_gke_cluster.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_secret" "tenzir_platform_secrets" {
  metadata {
    name      = "tenzir-platform-secrets"
    namespace = "default"
  }
  type = "Opaque"
  data = {
    "PRIVATE_OIDC_PROVIDER_CLIENT_SECRET"      = var.private_oidc_provider_client_secret
    "TENZIR_PLATFORM_INTERNAL_APP_API_KEY"     = var.tenzir_platform_internal_app_api_key
    "AUTH_SECRET"                              = var.tenzir_platform_internal_auth_secret
    "TENZIR_PLATFORM_POSTGRES_USER"            = var.tenzir_platform_postgres_user
    "TENZIR_PLATFORM_POSTGRES_PASSWORD"        = var.tenzir_platform_postgres_password
    "TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY" = var.tenant_manager_tenant_token_encryption_key
    "BLOB_STORAGE_ACCESS_KEY_ID"               = var.blob_storage_access_key_id
    "BLOB_STORAGE_SECRET_ACCESS_KEY"           = var.blob_storage_secret_access_key
  }
}

