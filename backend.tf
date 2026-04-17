# S3 bucket & DynamoDB needed!

# terraform {
#   backend "s3" {
#     bucket         = "eks-corp-terraform-state"
#     key            = "prod/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "eks-corp-terraform-locks"
#     encrypt        = true
#   }
# }