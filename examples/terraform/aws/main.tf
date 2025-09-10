module "bootstrap" {
  source = "./modules/bootstrap"
  
  domain_name      = var.domain_name
  random_subdomain = var.random_subdomain
}