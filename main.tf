locals {
  name_prefix = "sandbox-aw"
  tags = {
    Purpose = "CE 12 - Coaching 11"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"
  name    = "${local.name_prefix}-vpc"

  cidr             = "10.0.0.0/16"
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway           = false
  single_nat_gateway           = true
  enable_dns_hostnames         = true
  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-rds-sg"
  description = "MySQL security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

module "db" {
  source     = "terraform-aws-modules/rds/aws"
  version    = "6.10.0"
  identifier = "${local.name_prefix}-rds"

  # Supported - https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.Support.html
  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 22
  storage_encrypted     = false

  db_name  = "sandboxdb"
  username = "admin"
  port     = 3306

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  skip_final_snapshot = true
  deletion_protection = false

  tags = local.tags
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  value = module.vpc.natgw_ids
}