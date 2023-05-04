resource "aws_security_group" "jenkins" {
  name_prefix = "jenkins-"
  description = "Security group for Jenkins"

  vpc_id = "vpc-044015a23d01c789a"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-security-group"
  }
}
