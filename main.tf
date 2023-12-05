terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"  name = "my-vpc"
  cidr = "172.31.0.0/16"  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = ["172.31.1.0/24", "172.31.2.0/24"]
  public_subnets  = ["172.31.101.0/24", "172.31.102.0/24"]
  database_subnets    = ["172.31.3.0/24", "172.31.4.0/24"] 
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = true
}

resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "key_name" {
  type        = string
  default     = "terraform_key"
  description = "pem file"
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa_4096.private_key_pem
  filename = var.key_name
}

resource "aws_launch_configuration" "web_server_launch" {
  name   = "web_server_launch"
  image_id      = "ami-000bb0246fe29a4e8"  # 사용할 AMI ID로 교체해야 합니다.
  instance_type = "t2.micro"    # 원하는 인스턴스 유형으로 교체해야 합니다.
  key_name      = "terraform_key"
  security_groups = [aws_security_group.web_server_sg.id]
  associate_public_ip_address = true     lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_server_asg" {
  name           = "web_asg"
  launch_configuration  = aws_launch_configuration.web_server_launch.name
  min_size              = 2
  max_size              = 2
  desired_capacity      = 2
  vpc_zone_identifier   = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]] # 사용할 서브넷 ID로 교체해야 합니다.
  target_group_arns     = [aws_lb_target_group.web_lb_tg.arn]
  lifecycle {
    create_before_destroy = true
  }  tag {
    key                 = "Name"
    value               = "WebAutoScalingInstance"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "app_server_launch" {
  name   = "app_server_launch"
  image_id      = "ami-000bb0246fe29a4e8"  # 사용할 AMI ID로 교체해야 합니다.
  instance_type = "t2.micro"    # 원하는 인스턴스 유형으로 교체해야 합니다.
  key_name      = "terraform_key"
  security_groups = [aws_security_group.app_server_sg.id]


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_server_asg" {
  name           = "app_asg"
  launch_configuration  = aws_launch_configuration.app_server_launch.name
  min_size              = 2
  max_size              = 2
  desired_capacity      = 2
  vpc_zone_identifier   = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]] # 사용할 서브넷 ID로 교체해야 합니다.
  target_group_arns     = [aws_lb_target_group.app_lb_tg.arn]
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "AppAutoScalingInstance"
    propagate_at_launch = true
  }
}
resource "aws_security_group" "web_server_sg" {
  name        = "web_server_sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_server_sg" {
  name        = "app_server_sg"
  description = "Security group for app servers"
  vpc_id      = module.vpc.vpc_id  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web Load Balancer (Application)
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server_sg.id]
  subnets            = module.vpc.public_subnets  tags = {
    Environment = "production"
  }
}

# Web Load Balancer Listener
resource "aws_lb_listener" "web_lb_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_lb_tg.arn
  }
}

# Web Load Balancer Target Group
resource "aws_lb_target_group" "web_lb_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id   health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/sample"
    protocol            = "HTTP"
    matcher             = "200"
  }  tags = {
    Environment = "production"
  }
}

# App Load Balancer (Application)
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_server_sg.id]
  subnets            = module.vpc.private_subnets  tags = {
    Environment = "production"
  }
}

# App Load Balancer Listener
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_lb_tg.arn
  }
}

# App Load Balancer Target Group
resource "aws_lb_target_group" "app_lb_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id   health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }  tags = {
    Environment = "production"
  }
}

resource "aws_db_instance" "primary" {
  identifier           = "my-primary-db"
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  db_name              = "mydb"
  username             = "test"
  password             = "testtest"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.my_db_sg.id]
  availability_zone    = "ap-northeast-2a"
  backup_retention_period = 1
  skip_final_snapshot     = true
}

# Read Replica 생성
resource "aws_db_instance" "read_replica" {
  identifier           = "my-read-replica"
  replicate_source_db  = aws_db_instance.primary.identifier
  instance_class       = "db.t2.micro"
  availability_zone    = "ap-northeast-2c"
  vpc_security_group_ids = [aws_security_group.my_db_sg.id]
  depends_on = [aws_db_instance.primary]
  # Read Replica는 자동 백업, 스냅샷, 수정이 비활성화되어야 할 수 있습니다.
  backup_retention_period = 0
  skip_final_snapshot     = true
}

# 데이터베이스 서브넷 그룹
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my_db_subnet_group"
  subnet_ids = [module.vpc.database_subnets[0], module.vpc.database_subnets[1]]
}

# RDS 인스턴스를 위한 보안 그룹
resource "aws_security_group" "my_db_sg" {
  name   = "my_db_sg"
  vpc_id = module.vpc.vpc_id
}