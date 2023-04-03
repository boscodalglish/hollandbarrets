locals {
  region = "eu-west-1"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr

  azs              = var.azs
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  private_subnet_names = ["Private Subnet One", "Private Subnet Two", "Private Subnet Three"]

  enable_ipv6 = true

  manage_default_route_table = true
  default_route_table_tags   = { Name = "${var.name}-default" }

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  map_public_ip_on_launch = true

  public_subnet_tags = {
    Name = "internet-public"
  }

  public_subnet_tags_per_az = {
    "${local.region}a" = {
      "availability-zone" = "${local.region}a"
    }
  }

  vpc_tags = {
    Name = "vpc-${var.name}"
  }
}
