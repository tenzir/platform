# EFS filesystem for CA certificate storage
resource "aws_efs_file_system" "ca_storage" {
  creation_token = "tenzir-ca-storage"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"

  tags = {
    Name = "tenzir-ca-storage"
  }
}

# Security group for EFS access
resource "aws_security_group" "efs" {
  name        = "tenzir-efs-sg"
  description = "Security group for EFS access"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-efs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  security_group_id            = aws_security_group.efs.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.lambda.id
}

# EFS mount targets for each subnet where Lambda functions might run
resource "aws_efs_mount_target" "platform" {
  file_system_id  = aws_efs_file_system.ca_storage.id
  subnet_id       = aws_subnet.platform.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "nodes" {
  file_system_id  = aws_efs_file_system.ca_storage.id
  subnet_id       = aws_subnet.nodes.id
  security_groups = [aws_security_group.efs.id]
}

# Create the ca.pem file in the EFS filesystem
resource "aws_efs_file_system_policy" "ca_storage_policy" {
  file_system_id = aws_efs_file_system.ca_storage.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# EFS Access Point for the CA file
resource "aws_efs_access_point" "ca_file" {
  file_system_id = aws_efs_file_system.ca_storage.id
  
  posix_user {
    gid = 1001
    uid = 1001
  }
  
  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = "755"
    }
  }

  tags = {
    Name = "tenzir-ca-access-point"
  }
}

