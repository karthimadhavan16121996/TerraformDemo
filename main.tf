provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "demovpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.demovpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.demovpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_c" {
  vpc_id                  = aws_vpc.demovpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "demoigw" {
  vpc_id = aws_vpc.demovpc.id
}

resource "aws_route_table" "demoroute" {
  vpc_id = aws_vpc.demovpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demoigw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.demoroute.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.demoroute.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet_c.id
  route_table_id = aws_route_table.demoroute.id
}

resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.demovpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

resource "aws_instance" "demo1" {
  ami           = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  depends_on = [
         aws_internet_gateway.demoigw,
         aws_route_table_association.a
  ]
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              echo "<h1>Home page!</h1>" >> /var/www/html/index.html
              echo "<p>(Instance A)</p>" >> /var/www/html/index.html
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_instance" "demo2" {
  ami           = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  depends_on = [
         aws_internet_gateway.demoigw,
         aws_route_table_association.b
  ]
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              mkdir -p /var/www/html/images
              echo "<h1>Images!</h1>" >> /var/www/html/images/index.html
              echo "<p>(Instance B)</p>" >> /var/www/html/images/index.html
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_instance" "demo3" {
  ami           = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_c.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  depends_on = [
         aws_internet_gateway.demoigw,
         aws_route_table_association.c
  ]
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              mkdir -p /var/www/html/register
              echo "<h1>Register!</h1>" >> /var/www/html/register/index.html
              echo "<p>(Instance C)</p>" >> /var/www/html/register/index.html
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_lb" "demoalb" {
  name               = "demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, aws_subnet.subnet_c.id]
}

resource "aws_lb_target_group" "demotg1" {
  name     = "demo-tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demovpc.id
}

resource "aws_lb_target_group" "demotg2" {
  name     = "demo-tg2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demovpc.id
}

resource "aws_lb_target_group" "demotg3" {
  name     = "demo-tg3"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demovpc.id
}

resource "aws_lb_target_group_attachment" "demotga1" {
  target_group_arn = aws_lb_target_group.demotg1.arn
  target_id        = aws_instance.demo1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "demotga2" {
  target_group_arn = aws_lb_target_group.demotg2.arn
  target_id        = aws_instance.demo2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "demotga3" {
  target_group_arn = aws_lb_target_group.demotg3.arn
  target_id        = aws_instance.demo3.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.demoalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demotg1.arn
  }
}

resource "aws_lb_listener_rule" "images_rule" {
  listener_arn = aws_lb_listener.listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demotg2.arn
  }
  condition {
    path_pattern {
      values = ["/images*"]
    }
  }
}

resource "aws_lb_listener_rule" "register_rule" {
  listener_arn = aws_lb_listener.listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demotg3.arn
  }
  condition {
    path_pattern {
      values = ["/register*"]
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.demoalb.dns_name
}
