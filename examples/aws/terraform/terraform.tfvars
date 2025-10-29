domain_name = "tenzr.click"
random_subdomain = true

# OIDC Configuration Options:
## Option 1: Create a new AWS Cognito user pool as part of the deployment (default)
# use_external_oidc = false

## Option 2: Use external OIDC provider
# use_external_oidc = true
# external_oidc_issuer_url = "https://your-oidc-provider.com"
# external_oidc_client_id = "your-client-id"
# external_oidc_client_secret = "your-client-secret"

## Additional environment variables for API service
# api_service_extra_environment_variables = {
#   "TENANT_MANAGER_AUTH__SINGLE_USER_MODE" = true
#   "TENANT_MANAGER_AUTH__ISSUER_URL" = "http://platform:5000/oidc"
#   "TENANT_MANAGER_AUTH__PUBLIC_BASE_URL" = "${TENZIR_PLATFORM_API_ENDPOINT}/oidc"
#   "TENANT_MANAGER_AUTH__APP_AUDIENCE" = "tenzir-app"
#   "TENANT_MANAGER_AUTH__APP_REDIRECT_URLS" = "${TENZIR_PLATFORM_UI_ENDPOINT}/login/oauth/callback"
# }

