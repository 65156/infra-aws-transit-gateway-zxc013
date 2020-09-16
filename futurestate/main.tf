module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 1.0"
  
  name        = "my-tgw"
  description = "My TGW shared with several other AWS accounts"
  
  enable_auto_accept_shared_attachments = true

  vpc_attachments = {
    vpc = {
      vpc_id       = module.vpc.vpc_id
      subnet_ids   = module.vpc.private_subnets
      dns_support  = true
      ipv6_support = true

      tgw_routes = [
        {
          destination_cidr_block = "30.0.0.0/16"
        },
        {
          blackhole = true
          destination_cidr_block = "40.0.0.0/20"
        }
      ]
    }
  }

  ram_allow_external_principals = true
  ram_principals = [307990089504]

  tags = {
    Purpose = "tgw-complete-example"
  }
}
/*
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "my-vpc"

  cidr = "10.10.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

  enable_ipv6                                    = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]
}
*/
