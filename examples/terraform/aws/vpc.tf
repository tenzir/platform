resource "aws_vpc" "tenzir" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tenzir-vpc"
  }
}

resource "aws_subnet" "nodes" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tenzir-nodes-subnet"
  }
}

resource "aws_subnet" "platform" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "tenzir-platform-subnet"
  }
}

# An RDS instance needs at least two subnets in two different
# availability zones, for whatever reason.
resource "aws_subnet" "postgres1" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "tenzir-postgres-subnet1"
  }
}

resource "aws_subnet" "postgres2" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "tenzir-postgres-subnet2"
  }
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "tenzir-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-vpc-endpoint-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https" {
  security_group_id            = aws_security_group.vpc_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.lambda.id
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.tenzir.id
  service_name        = "com.amazonaws.eu-west-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "tenzir-secrets-manager-endpoint"
  }
}

# # Route 53 Resolver VPC endpoint for DNS resolution
# resource "aws_vpc_endpoint" "route53_resolver" {
#   vpc_id              = aws_vpc.tenzir.id
#   service_name        = "com.amazonaws.eu-west-1.route53resolver"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = [aws_subnet.platform.id]
#   security_group_ids  = [aws_security_group.vpc_endpoint.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "tenzir-route53-resolver-endpoint"
#   }
# }

