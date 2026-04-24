terraform {
  backend "s3" {
    bucket         = "eks-corp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "eks-corp-terraform-locks"
    encrypt        = true
  }
}
