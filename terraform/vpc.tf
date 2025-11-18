resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_subnet" "a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, 0)
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-subnet-a"
  }
}

resource "aws_subnet" "b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, 1)
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-subnet-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.b.id
  route_table_id = aws_route_table.public.id
}
