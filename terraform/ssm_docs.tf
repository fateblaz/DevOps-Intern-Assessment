resource "aws_ssm_document" "mongo_snapshot" {
  name          = "${var.name_prefix}-mongo-snapshot"
  document_type = "Command"

  content = templatefile("${path.module}/snapshot_ssm_doc.json.tpl", {
    name_prefix = var.name_prefix
    aws_region  = var.aws_region
  })

  tags = {
    Name = "${var.name_prefix}-mongo-snapshot"
  }
}

resource "aws_ssm_document" "mongo_restore" {
  name          = "${var.name_prefix}-mongo-restore"
  document_type = "Command"

  content = templatefile("${path.module}/restore_ssm_doc.json.tpl", {
    name_prefix = var.name_prefix
    aws_region  = var.aws_region
  })

  tags = {
    Name = "${var.name_prefix}-mongo-restore"
  }
}

resource "aws_ssm_document" "mongo_replica_init" {
  name          = "${var.name_prefix}-mongo-replica-init"
  document_type = "Command"

  content = templatefile("${path.module}/scripts/replica_init_doc.json.tpl", {
    aws_region         = var.aws_region
    admin_ssm_user     = var.admin_ssm_user
    admin_ssm_password = var.admin_ssm_password
    primary_ip         = aws_instance.primary.private_ip
    secondary_ip       = aws_instance.secondary.private_ip
  })

  tags = {
    Name = "${var.name_prefix}-mongo-replica-init"
  }
}
