terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"

    }
  }

  backend "s3" {
    bucket         = "hb-test-tfstate"
    key            = "hb-test-tfstate.tfstate"
    dynamodb_table = "terraform-state-lock-dynamo"
    region         = "eu-west-1"
    encrypt        = "true"
  }
}

provider "aws" {
  region      = "eu-west-1"
  max_retries = 5
  access_key  = var.access_key
  secret_key  = var.secret_key
  default_tags {
    tags = {
      "project"     = "handb"
      "region"      = "eu-west-1"
      "environment" = "non-prod"
      "repo"        = "https://github.com/boscodalglish/hollandbarrets"
      "email"       = "dalglishfernandesuk@gmail.com"
      "owner"       = "Dalglish Fernandes"
      "live"        = "no"
    }
  }
}

