data "aws_instances" "private_instances" {
  instance_tags = {
    Name = "${var.name}-instance-private"
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name}-instance-private"]
  }
  instance_state_names = ["running"]
}

data "aws_instances" "public_instances" {
  instance_tags = {
    Name = "${var.name}-instance-public"
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name}-instance-public"]
  }
  instance_state_names = ["running"]
}


# /* Private SG and rules */

resource "aws_security_group" "private_alb_sg" {
  name        = "private_alb_sg"
  description = "Private ALB SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Private ALB SG"
  }
}

resource "aws_security_group" "public_alb_sg" {
  name        = "public_alb_sg"
  description = "Public ALB SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Public ALB SG"
  }
}

/*Private ALB*/
resource "aws_alb_target_group" "private_http" {

  name        = "instance-private-http"
  port        = "80"
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    matcher = "200-299"
    path    = "/"
  }

  vpc_id = var.vpc_id

}

resource "aws_lb_target_group_attachment" "private_test" {
  count            = length(data.aws_instances.private_instances.ids)
  target_group_arn = aws_alb_target_group.private_http.arn
  target_id        = data.aws_instances.private_instances.ids[count.index]
  port             = 80
}

resource "aws_alb" "private" {

  name            = "instance-private-alb"
  subnets         = ["${var.private_subnets[0]}", "${var.private_subnets[1]}", "${var.private_subnets[2]}"]
  security_groups = [aws_security_group.private_alb_sg.id]
  internal        = true

}

resource "aws_alb_listener" "private_http" {

  load_balancer_arn = aws_alb.private.id
  port              = 80
  protocol          = "HTTP"

  #   ssl_policy = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  #   certificate_arn = element(
  #     aws_acm_certificate_validation.private_cert.*.certificate_arn,
  #     0,
  #   )

  default_action {
    target_group_arn = aws_alb_target_group.private_http.id
    type             = "forward"
  }

}



/*Public ALB*/
resource "aws_alb_target_group" "public_http" {

  name        = "instance-public-http"
  port        = "80"
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    matcher = "200-299"
    path    = "/"
  }

  vpc_id = var.vpc_id

}

resource "aws_lb_target_group_attachment" "public_test" {
  count            = length(data.aws_instances.public_instances.ids)
  target_group_arn = aws_alb_target_group.public_http.arn
  target_id        = data.aws_instances.public_instances.ids[count.index]
  port             = 80
}

resource "aws_alb" "public" {

  name            = "instance-public-alb"
  subnets         = ["${var.public_subnets[0]}", "${var.public_subnets[1]}", "${var.public_subnets[2]}"]
  security_groups = [aws_security_group.public_alb_sg.id]
  internal        = false

}

resource "aws_alb_listener" "public_http" {

  load_balancer_arn = aws_alb.public.id
  port              = 80
  protocol          = "HTTP"

  #   ssl_policy = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  #   certificate_arn = element(
  #     aws_acm_certificate_validation.private_cert.*.certificate_arn,
  #     0,
  #   )

  default_action {
    target_group_arn = aws_alb_target_group.public_http.id
    type             = "forward"
  }

}
