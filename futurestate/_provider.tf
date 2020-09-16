terraform {
  backend "gcs" {
    bucket = "terraform-statefiles-xjdfh3"
    prefix = "aws/transit-gateway"
  }
}

data "terraform_remote_state" "vpn" {
  backend = "gcs"
  config = {
    bucket = "terraform-statefiles-xjdfh3"
    prefix = "multicloud/vpn-aws-gcp"
  }
}

provider "aws" {
  region = var.aws_default_region
}

provider "google" {
  region = var.gcp_default_region
}



