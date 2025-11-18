terraform {
  backend "s3" {
    bucket         = "remote_backend_bucket"
    key            = "state/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks-sync-system"
    encrypt        = true
  }
}
