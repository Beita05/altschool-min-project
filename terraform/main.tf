provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    "Name" = "my_vpc"
  }
}

resource "aws_internet_gateway" "my_ig" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_ig"
  }
}

resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_ig.id
  }
  tags = {
    Name = "public_RT"
  }
}

resource "aws_route_table_association" "my-public-subnet1-association" {
  subnet_id      = aws_subnet.my-public-subnet1.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "my-public-subnet2-association" {
  subnet_id      = aws_subnet.my-public-subnet2.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_subnet" "my-public-subnet1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    "Name" = "my-public-subnet1"
  }
}

resource "aws_subnet" "my-public-subnet2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    "Name" = "my-public-subnet2"
  }
}

resource "aws_security_group" "my-lb-sg" {
  name        = "my-lb-sg"
  description = "Load balancer security group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "my-instance-sg" {
  name        = "my-instance-sg"
  description = "Allow SSH, HTTP and HTTPS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    description     = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.my-lb-sg.id]
  }
  ingress {
    description     = "HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.my-lb-sg.id]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_instance" "server1" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terraformKey"
  security_groups   = [aws_security_group.my-instance-sg.id]
  subnet_id         = aws_subnet.my-public-subnet1.id
  availability_zone = "us-east-1a"

  tags = {
    Name   = "Server1"
  }
}

resource "aws_instance" "server2" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terraformKey"
  security_groups   = [aws_security_group.my-instance-sg.id]
  subnet_id         = aws_subnet.my-public-subnet1.id
  availability_zone = "us-east-1a"

  tags = {
    Name   = "Server2"
  }
}

resource "aws_instance" "server3" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  key_name          = "terraformKey"
  security_groups   = [aws_security_group.my-instance-sg.id]
  subnet_id         = aws_subnet.my-public-subnet2.id
  availability_zone = "us-east-1b"

  tags = {
    Name   = "Server3"
  }
}


resource "local_file" "instances_public_IPs" {
  filename = "/home/deehaz/Documents/terraform/mini-project/ansible/host-inventory"
  content  = <<EOT
    ${aws_instance.server1.public_ip}
    ${aws_instance.server2.public_ip}
    ${aws_instance.server3.public_ip}
   EOT
}

resource "aws_lb" "my-lb" {
  name                       = "my-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.my-lb-sg.id]
  subnets                    = [aws_subnet.my-public-subnet1.id, aws_subnet.my-public-subnet2.id]
  enable_deletion_protection = false
  depends_on                 = [aws_instance.server1, aws_instance.server2, aws_instance.server3]
}

resource "aws_lb_target_group" "my-lb-tgp" {
  name        = "my-lb-tgp"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "my-lb-lr" {
  load_balancer_arn = aws_lb.my-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-lb-tgp.arn
  }
}

resource "aws_lb_listener_rule" "my-lb-lr-rl" {
  listener_arn = aws_lb_listener.my-lb-lr.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-lb-tgp.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_lb_target_group_attachment" "my-tg-grp-atch1" {
  target_group_arn = aws_lb_target_group.my-lb-tgp.arn
  target_id        = aws_instance.server1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "my-tg-grp-atch2" {
  target_group_arn = aws_lb_target_group.my-lb-tgp.arn
  target_id        = aws_instance.server2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "my-tg-grp-atch3" {
  target_group_arn = aws_lb_target_group.my-lb-tgp.arn
  target_id        = aws_instance.server3.id
  port             = 80

}

output "lb_dns_name" {
  value = aws_lb.my-lb.dns_name
}