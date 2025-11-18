data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "ec2_policy" {
  name = "${var.name_prefix}-ec2-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeSnapshots",
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.ec2_role.name
}
