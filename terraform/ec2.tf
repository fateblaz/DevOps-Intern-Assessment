locals {
  userdata_common = templatefile("${path.module}/scripts/userdata_common.sh.tpl", {
    ssm_param_user     = var.admin_ssm_user,
    ssm_param_password = var.admin_ssm_password,
    docker_image       = var.docker_image,
    data_device        = var.data_device,
    aws_region         = var.aws_region,
    mongo_user         = "mongo_admin"
  })

  userdata_primary = templatefile("${path.module}/scripts/userdata_primary.sh.tpl", {
    ssm_param_user     = var.admin_ssm_user,
    ssm_param_password = var.admin_ssm_password,
    docker_image       = var.docker_image,
    data_device        = var.data_device,
    aws_region         = var.aws_region,
    mongo_user         = "mongo_admin",
    create_sample      = true
  })
}

# Primary
resource "aws_instance" "primary" {
  ami                    = var.ami
  instance_type          = var.primary_instance_type
  subnet_id              = aws_subnet.a.id
  vpc_security_group_ids = [aws_security_group.mongo_sg.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.userdata_primary
  tags                   = { Name = "${var.name_prefix}-primary" }
}

resource "aws_ebs_volume" "primary_data" {
  availability_zone = aws_subnet.a.availability_zone
  size              = var.data_volume_size_gb
  encrypted         = true
  tags              = { Name = "${var.name_prefix}-primary-data" }
}

resource "aws_volume_attachment" "primary_attach" {
  device_name = var.data_device
  volume_id   = aws_ebs_volume.primary_data.id
  instance_id = aws_instance.primary.id
}

# Secondary
resource "aws_instance" "secondary" {
  ami                    = var.ami
  instance_type          = var.secondary_instance_type
  subnet_id              = aws_subnet.b.id
  vpc_security_group_ids = [aws_security_group.mongo_sg.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.userdata_common
  tags                   = { Name = "${var.name_prefix}-secondary" }
}

resource "aws_ebs_volume" "secondary_data" {
  availability_zone = aws_subnet.b.availability_zone
  size              = var.data_volume_size_gb
  encrypted         = true
  tags              = { Name = "${var.name_prefix}-secondary-data" }
}

resource "aws_volume_attachment" "secondary_attach" {
  device_name = var.data_device
  volume_id   = aws_ebs_volume.secondary_data.id
  instance_id = aws_instance.secondary.id
}

# Staging
resource "aws_instance" "staging" {
  ami                    = var.ami
  instance_type          = var.staging_instance_type
  subnet_id              = aws_subnet.b.id
  vpc_security_group_ids = [aws_security_group.mongo_sg.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.userdata_common
  tags                   = { Name = "${var.name_prefix}-staging" }
}

resource "aws_ebs_volume" "staging_data" {
  availability_zone = aws_subnet.b.availability_zone
  size              = var.data_volume_size_gb
  encrypted         = true
  tags              = { Name = "${var.name_prefix}-staging-data" }
}

resource "aws_volume_attachment" "staging_attach" {
  device_name = var.data_device
  volume_id   = aws_ebs_volume.staging_data.id
  instance_id = aws_instance.staging.id
}
