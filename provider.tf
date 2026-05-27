# ---- PROVIDER SETUP ----
# Declares plugin
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "aatu-terraform-state-2026"
    key    = "state.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = "eu-north-1" 
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}