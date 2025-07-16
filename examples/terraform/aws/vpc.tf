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
  map_public_ip_on_launch = false

  tags = {
    Name = "tenzir-platform-subnet"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tenzir-public-subnet"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "tenzir-public-subnet2"
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

resource "aws_route_table" "platform" {
  vpc_id = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-platform-rt"
  }
}


resource "aws_route_table_association" "nodes" {
  subnet_id      = aws_subnet.nodes.id
  route_table_id = aws_route_table.platform.id
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

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https_platform" {
  security_group_id = aws_security_group.vpc_endpoint.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_subnet.platform.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https_nodes" {
  security_group_id = aws_security_group.vpc_endpoint.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_subnet.nodes.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https_apprunner" {
  security_group_id            = aws_security_group.vpc_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.apprunner_ui.id
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

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.tenzir.id
  service_name        = "com.amazonaws.eu-west-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "tenzir-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.tenzir.id
  service_name        = "com.amazonaws.eu-west-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "tenzir-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.tenzir.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.platform.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::prod-eu-west-1-starport-layer-bucket/*"
        ]
      }
    ]
  })

  tags = {
    Name = "tenzir-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.tenzir.id
  service_name        = "com.amazonaws.eu-west-1.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "tenzir-sts-endpoint"
  }
}

resource "aws_internet_gateway" "tenzir" {
  vpc_id = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "tenzir-nat-eip"
  }
}

# For some reason, even when configuring a VPC endpoint for a private ECR
# registry with pull-through caching from the marketplace registry, the
# `docker pull` command still ends up with a public IP outside of the VPC.
# The AWS docs even mention that the initial pull from a pull-through cache
# requires public internet access, but never explain why. Conceptually it
# doesn't make any sense, but until we get time for deeper debugging we just
# have to give up and add NAT access to the outside world.
resource "aws_nat_gateway" "tenzir" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "tenzir-nat-gateway"
  }

  depends_on = [aws_internet_gateway.tenzir]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tenzir.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tenzir.id
  }

  tags = {
    Name = "tenzir-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "platform" {
  subnet_id      = aws_subnet.platform.id
  route_table_id = aws_route_table.platform.id
}

resource "aws_route" "nat_gateway" {
  route_table_id         = aws_route_table.platform.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.tenzir.id
}


