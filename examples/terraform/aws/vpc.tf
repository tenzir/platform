resource "aws_vpc" "tenzir" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tenzir-vpc"
  }
}

# resource "aws_internet_gateway" "tenzir" {
#   vpc_id = aws_vpc.tenzir.id

#   tags = {
#     Name = "tenzir-igw"
#   }
# }

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

resource "aws_subnet" "postgres" {
  vpc_id                  = aws_vpc.tenzir.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "tenzir-postgres-subnet"
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

# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.tenzir.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.tenzir.id
#   }

#   tags = {
#     Name = "tenzir-public-rt"
#   }
# }

# resource "aws_route_table_association" "nodes" {
#   subnet_id      = aws_subnet.nodes.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "platform" {
#   subnet_id      = aws_subnet.platform.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.tenzir.id

#   tags = {
#     Name = "tenzir-private-rt"
#   }
# }

# resource "aws_route_table_association" "postgres" {
#   subnet_id      = aws_subnet.postgres.id
#   route_table_id = aws_route_table.private.id
# }