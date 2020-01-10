provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-alex-bucket"
    key    = "prod/test_django/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-alex-bucket"
    key    = "prod/test_django/network/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

resource "aws_launch_configuration" "nginx" {
  name_prefix     = "nginx-HA-"
  image_id        = data.aws_ami.latest_ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.http_https.id]
  user_data       = templatefile("./user_data_nginx.tpl", { DJANGO_SECRET_KEY = data.aws_ssm_parameter.DJANGO_SECRET_KEY.value })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ha" {
  name                 = "asg-${aws_launch_configuration.nginx.name}"
  launch_configuration = aws_launch_configuration.nginx.id
  min_size             = length(data.terraform_remote_state.network.outputs.available_zones)
  max_size             = length(data.terraform_remote_state.network.outputs.available_zones)
  min_elb_capacity     = length(data.terraform_remote_state.network.outputs.available_zones)
  health_check_type    = "ELB"
  vpc_zone_identifier  = [join(", ", data.terraform_remote_state.network.outputs.public_subtens_id)]
  load_balancers       = [aws_elb.balancer.name]

  tag {
    key                 = "Name"
    value               = "nginx-HA"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_string" "DJANGO_SECRET_KEY" {
  length  = 45
  special = true
}

resource "aws_ssm_parameter" "DJANGO_SECRET_KEY" {
  name  = "/${var.env}/DJANGO_SECRET_KEY"
  type  = "SecureString"
  value = random_string.DJANGO_SECRET_KEY.result
}

data "aws_ssm_parameter" "DJANGO_SECRET_KEY" {
  name       = "/${var.env}/DJANGO_SECRET_KEY"
  depends_on = [aws_ssm_parameter.DJANGO_SECRET_KEY]
}

resource "aws_security_group" "http_https" {
  name        = "${var.env}-for-nginx"
  description = "${var.env}-SG-for-nginx"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_main_id

  dynamic "ingress" {
    for_each = var.sg_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "balancer" {
  name            = "ha-elb"
  subnets         = data.terraform_remote_state.network.outputs.public_subtens_id
  security_groups = [aws_security_group.http_https.id]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 10
  }
  tags = {
    Name = "HA-ELB"
  }
}
