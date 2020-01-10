provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-alex-bucket"
    key    = "prod/test_django/network/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-VPC"
  }
}

# resource "aws_subnet" "private" {
#   count             = length(data.aws_availability_zones.available.names)
#   vpc_id            = aws_vpc.main.id
#   availability_zone = data.aws_availability_zones.available.names[count.index]
#   cidr_block        = cidrsubnet("${aws_vpc.main.cidr_block}", 8, count.index + 1)
#
#   tags = {
#     Name = "${var.env}-private-subnet-${count.index + 1}"
#   }
# }

resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet("${aws_vpc.main.cidr_block}", 8, count.index + 10)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-gw"
  }
}

resource "aws_route_table" "prod-route" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.env}-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  route_table_id = aws_route_table.prod-route.id
  subnet_id      = element(aws_subnet.public[*].id, count.index)
}
