resource "aws_db_subnet_group" "tenzir" {
  name       = "tenzir-db-subnet-group"
  subnet_ids = [aws_subnet.postgres1.id, aws_subnet.postgres2.id]

  tags = {
    Name = "tenzir-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "tenzir-rds-sg"
  description = "Security group for Tenzir RDS instance"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.lambda.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres_apprunner" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.apprunner_ui.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres_ecs_gateway" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs_service.id
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "tenzir-postgres-password-v2-${module.bootstrap.subdomain_hex}"
  description             = "Password for Tenzir PostgreSQL database"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "tenzir_admin"
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.tenzir.endpoint
    port     = aws_db_instance.tenzir.port
    dbname   = aws_db_instance.tenzir.db_name
  })
}

resource "aws_secretsmanager_secret" "postgres_uri" {
  name                    = "tenzir-postgres-uri-${module.bootstrap.subdomain_hex}"
  description             = "PostgreSQL URI for Tenzir database connection"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "postgres_uri" {
  secret_id = aws_secretsmanager_secret.postgres_uri.id
  secret_string = "postgresql://${aws_db_instance.tenzir.username}:${urlencode(random_password.db_password.result)}@${aws_db_instance.tenzir.endpoint}/${aws_db_instance.tenzir.db_name}?sslmode=require"
}

# Generate 32 random bytes for tenant token encryption key (base64 encoded)
resource "random_bytes" "tenant_token_encryption_key" {
  length = 32
}

resource "aws_secretsmanager_secret" "tenant_manager_tenant_token_encryption_key" {
  name                    = "tenzir-tenant-token-encryption-key-${module.bootstrap.subdomain_hex}"
  description             = "Tenant token encryption key secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "tenant_manager_tenant_token_encryption_key" {
  secret_id     = aws_secretsmanager_secret.tenant_manager_tenant_token_encryption_key.id
  secret_string = random_bytes.tenant_token_encryption_key.base64
}

# Generate 32 random bytes for app API key (hex encoded)
resource "random_bytes" "tenant_manager_app_api_key" {
  length = 32
}

resource "aws_secretsmanager_secret" "tenant_manager_app_api_key" {
  name                    = "tenzir-tenant-manager-app-api-key-${module.bootstrap.subdomain_hex}"
  description             = "API key secret for tenant manager app"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "tenant_manager_app_api_key" {
  secret_id     = aws_secretsmanager_secret.tenant_manager_app_api_key.id
  secret_string = random_bytes.tenant_manager_app_api_key.hex
}

# Generate 64 random bytes for master seed (hex encoded)
resource "random_bytes" "workspace_secrets_master_seed" {
  length = 64
}

resource "aws_secretsmanager_secret" "workspace_secrets_master_seed" {
  name                    = "tenzir-workspace-secrets-master-seed-${module.bootstrap.subdomain_hex}"
  description             = "Master seed secret for workspace secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "workspace_secrets_master_seed" {
  secret_id     = aws_secretsmanager_secret.workspace_secrets_master_seed.id
  secret_string = random_bytes.workspace_secrets_master_seed.hex
}

# Generate 32 random bytes for auth secret (hex encoded)
resource "random_bytes" "auth_secret" {
  length = 32
}

resource "aws_secretsmanager_secret" "auth_secret" {
  name                    = "tenzir-auth-secret-${module.bootstrap.subdomain_hex}"
  description             = "Auth secret for UI Lambda"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "auth_secret" {
  secret_id     = aws_secretsmanager_secret.auth_secret.id
  secret_string = random_bytes.auth_secret.hex
}

resource "aws_db_instance" "tenzir" {
  identifier = "tenzir-postgres"

  engine         = "postgres"
  engine_version = "17.5"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "tenzir"
  username = "tenzir_admin"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.tenzir.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "tenzir-postgres"
  }
}