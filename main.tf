# Define AWS provider and set the region for resource provisioning
provider "aws" {
  region = "us-east-1"
}

# Create a Virtual Private Cloud to isolate the infrastructure
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "DjangoRDSVPC"
  }
}

# Route table for controlling traffic leaving the VPC
resource "aws_route_table" "default" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
  tags = {
    Name = "DjangoRDSRouteTable"
  }
}

# Internet Gateway to allow internet access to the VPC
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name = "DjangoRDSInternetGateway"
  }
}

# Subnet within VPC for resource allocation, in availability zone us-east-1a
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "DjangoRDSSubnet1"
  }
}

# Another subnet for redundancy, in availability zone us-east-1b
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "DjangoRDSSubnet2"
  }
}

# Associate subnets with route table for internet access
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.default.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.default.id
}

# DB subnet group for RDS instances, using the created subnets
resource "aws_db_subnet_group" "default" {
  name       = "docker-rds-subnet"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = {
    Name = "My RDS DB Subnet Group"
  }
}

# Security group for RDS, allows PostgreSQL traffic
resource "aws_security_group" "default" {
  vpc_id      = aws_vpc.default.id
  name        = "DjangoRDSSecurityGroup"
  description = "Allow all inbound traffic for RDS"
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_all"
  }
}

# Define variable for RDS password to avoid hardcoding secrets
variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

# RDS instance for Django backend, publicly accessible
resource "aws_db_instance" "default" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = "db.t3.micro"
  identifier             = "my-django-rds"
  db_name                = "djangodockerdb"
  username               = "adam"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
  multi_az               = false
  tags = {
    Name = "DjangoDockerRDS"
  }
}
