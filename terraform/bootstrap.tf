resource "aws_s3_bucket" "tfstate" {
  count  = length(var.tfstate_bucket) > 0 ? 1 : 0
  bucket = var.tfstate_bucket
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = var.tfstate_bucket
    Env  = "bootstrap"
  }
}
