# A project can only have a single brand, and the brand for a custom IAP oauth
# provider must be 'Internal'.

resource "google_iap_brand" "project_brand" {
  # Note: This must be changed to a valid email address of
  # a person with access to this project.
  support_email     = "support@platform.example"
  application_title = "Cloud IAP protected Application"
  project = data.google_client_config.default.project
}
resource "google_iap_client" "project_client" {
  display_name = "IAP OAuth Client"
  brand        =  google_iap_brand.project_brand.name
}

resource "kubernetes_secret" "iap_oauth_secret" {
  metadata {
    name      = "iap-oauth-credentials"
    namespace = "default"
  }

  data = {
    client_id     = google_iap_client.project_client.client_id
    client_secret = google_iap_client.project_client.secret
  }

  type = "Opaque"
}