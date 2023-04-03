locals {
  name                   = "holland and Barrett"
  region                 = "eu-west-1"
  cidr                   = "10.0.0.0/16"
  beta_aws_account       = "090861786163"
  enable_public_subnets  = true
  enable_private_subnets = true
  enable_db_subnets      = false
}

module "vpc" {
  source           = "../modules/vpc"
  cidr             = local.cidr
  name             = "VPC-hb"
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
}

module "autoscaler" {
  source                    = "../modules/autoscaler"
  tags                      = var.tags
  enable_public_subnets     = local.enable_public_subnets
  enable_private_subnets    = local.enable_private_subnets
  enable_db_subnets         = local.enable_db_subnets
  public_subnets            = module.vpc.public_subnets
  public_sg_ist             = module.network.security_group_Public_SG_allow_tls_id
  target_group_arns_public  = module.alb.alb_public_arn
  private_subnets           = module.vpc.private_subnets
  private_sg_ist            = module.network.security_group_Private_SG_allow_tls_id
  target_group_arns_private = module.alb.alb_private_arn
  db_subnets                = module.vpc.database_subnets
  db_sg_ist                 = module.network.security_group_DB_SG_allow_tls_id
}

module "dynamodb_state" {
  source          = "../modules/dynamodb_state_lock"
  dynamo_db_state = "terraform-state-lock-dynamo"
}

module "alb" {
  source          = "../modules/alb"
  name            = "hb-project"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
}

module "network" {
  source         = "../modules/network"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
}
