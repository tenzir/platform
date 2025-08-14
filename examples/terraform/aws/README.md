# Setup

```
# 1. Create ECR repos for lambdas
terraform apply -m module.bootstrap

# 2. Upload container images
make push

# 3. 
