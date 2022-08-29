terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
provider "aws" {
  region     = "${var.region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}
# create vpc
resource "aws_vpc" "vpc1" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "vpc1"
  }
}
# create subnets
resource "aws_subnet" "pub1" {
  vpc_id     = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2a"
  tags = {
    Name = "pub1"
  }
}
resource "aws_subnet" "pub2" {
  vpc_id     = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2b"
  tags = {
    Name = "pub2"
  }
}
resource "aws_subnet" "dmz1" {
  vpc_id     = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2a"
  tags = {
    Name = "dmz1"
  }
}
resource "aws_subnet" "dmz2" {
  vpc_id     = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.3.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2b"
  tags = {
    Name = "dmz2"
  }
}
resource "aws_subnet" "pri1" {
  vpc_id    = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.4.0/24"
  availability_zone = "us-east-2a"
 tags = {
    Name = "pri1"
  }
}
resource "aws_subnet" "pri2" {
  vpc_id     = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.5.0/24"
  availability_zone = "us-east-2b"
  tags = {
    Name = "pri2"
  }
}
# create internet gate way
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc1.id}"

  tags = {
    Name = "igw"
  }
}
# create route tables
resource "aws_route_table" "pubrt" {
  vpc_id = "${aws_vpc.vpc1.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "pubrt"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_route_table.pubrt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_route_table.pubrt.id
}
resource "aws_route_table" "dmzrt" {
  vpc_id = "${aws_vpc.vpc1.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "dmzrt"
  }
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.dmz1.id
  route_table_id = aws_route_table.dmzrt.id
}
resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.dmz2.id
  route_table_id = aws_route_table.dmzrt.id
}
resource "aws_route_table" "prirt" {
  vpc_id = "${aws_vpc.vpc1.id}"

  tags = {
    Name = "prirt"
  }
}
resource "aws_route_table_association" "e" {
  subnet_id      = aws_subnet.pri1.id
  route_table_id = aws_route_table.prirt.id
}
resource "aws_route_table_association" "f" {
  subnet_id      = aws_subnet.pri2.id
  route_table_id = aws_route_table.prirt.id
}
#security group for LB and asg
resource "aws_security_group" "lbsg" {
  name        = "lbsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.vpc1.id}"

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "lbsg"
} 
}
resource "aws_alb" "lb1" {
  name            = "lb1"
  security_groups = ["${aws_security_group.lbsg.id}"]
  subnets         = ["${aws_subnet.pub1.id}" , "${aws_subnet.pub2.id}"]
}
resource "aws_alb_target_group" "tg1" {
  name     = "tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc1.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/login"
    port = 80
  }
}
resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.lb1.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.tg1.arn}"
    type             = "forward"
  }
}
