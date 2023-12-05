resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Security group for public web servers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Security group for private app servers"
  vpc_id      = module.vpc.vpc_id

  // 예를 들어, 특정 포트에서의 내부 통신만 허용하는 규칙을 설정
}

// 라우팅 테이블과 연결을 위한 추가적인 Terraform 코드가 필요합니다.