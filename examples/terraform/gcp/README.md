# GCP Deployment using Terraform

This example shows how to deploy the complete platform stack inside GCP.

The platform services are deployed as kubernetes services to GKE.

All endpoints are protected by Cloud IAP.

Note that it is not possible to do the deployment in one
step.

   1. Fill out the `terraform.tfvars`
   2. `terraform apply -target=module.bootstrap`
   3. Upload platform images to created Artifact Registry instance
   4. `terraform apply`
   5. Point your DNS entry towards the created public IP address
