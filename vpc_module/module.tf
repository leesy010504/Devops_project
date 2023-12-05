module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "172.31.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = ["172.31.1.0/24", "172.31.2.0/24"]
  public_subnets  = ["172.31.101.0/24", "172.31.102.0/24"]
  database_subnets    = ["172.31.3.0/24", "172.31.4.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
}