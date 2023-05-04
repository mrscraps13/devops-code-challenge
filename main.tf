provider "aws" {
  region = "us-east-2"
}
##variables section: 
# Define variables
variable "aws_key_pair" "my_key_pair" {
  description = "Key"
  key_name    = "dmmylfapp"
  public_key  = file("./dmmylfapp.pem")
}

variable "vpc_id" {
  type    = string
  default = "vpc-044015a23d01c789a"
}

variable "public_subnet_id" {
  type    = string
  default = "subnet-05df45302a116e977"
}

variable "private_subnet_id" {
  type    = string
  default = "subnet-08caa100f486efbf8"
}

variable "frontend_app_ecr_uri" {
  type    = string
  default = "224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-frontend-app"
}

variable "backend_app_ecr_uri" {
  type    = string
  default = "224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-backend-app"
}


#assuming vpc exsists* 
#moving jenkins server and couple others to aws python cdk
/*
resource "aws_instance" "jenkins_server" {
  ami           = "ami-062531c465b1004a1"
  instance_type = "t4g.nano"
  key_name      = "aws_key_pair"
  subnet_id     = "subnet-05df45302a116e977"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y java-1.8.0-openjdk-devel
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              sudo yum install -y jenkins
              sudo systemctl start jenkins
              sudo systemctl enable jenkins
              
              # Generate random username and password for Jenkins
              JENKINS_USER="dmjenkinslfapp"
              JENKINS_PASS="u^d8&mW7#n@zrT9*"
              echo "Username: $JENKINS_USER" > /var/lib/jenkins/secrets/initialAdminPassword
              echo "Password: $JENKINS_PASS" >> /var/lib/jenkins/secrets/initialAdminPassword
              
              EOF

  tags = {
    Name = "jenkins-server"
  }
}

resource "aws_security_group" "jenkins_sg" {
  name_prefix = "jenkins-sg-"
  vpc_id = "vpc-044015a23d01c789a"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "jenkins_server_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}
*/
#############INF:  vpc, route table, ecs cluster and defns #################

# Segment 1: Create VPC and subnets
resource "aws_vpc" "ecs_cluster_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "ecs_cluster_subnet_1" {
  vpc_id     = aws_vpc.ecs_cluster_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "ecs_cluster_subnet_2" {
  vpc_id     = aws_vpc.ecs_cluster_vpc.id
  cidr_block = "10.0.2.0/24"
}

# Segment 2: Create security groups
resource "aws_security_group" "ecs_cluster_security_group" {
  name_prefix = "ecs_cluster_security_group_"
  description = "Security group for ECS cluster"

  vpc_id = aws_vpc.ecs_cluster_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

resource "aws_security_group" "ecs_cluster_lb_security_group" {
  name_prefix = "ecs_cluster_lb_security_group_"
  description = "Security group for ECS cluster load balancer"

  vpc_id = aws_vpc.ecs_cluster_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Segment 3: Create IAM roles
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}


# segment 5: create ecs service

resource "aws_ecs_service" "frontend_app" {
  name            = "my-frontend-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend_app.arn
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "my-frontend-app"
    container_port   = 3000
  }

  network_configuration {
    security_groups = [aws_security_group.ecs.id]
    subnets         = [aws_subnet.public.id]
  }

  lifecycle {
    ignore_changes = [
      platform_version,
    ]
  }

  depends_on = [
    aws_lb_listener.frontend,
  ]
}

resource "aws_ecs_service" "backend_app" {
  name            = "my-backend-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_app.arn
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "my-backend-app"
    container_port   = 8080
  }

  network_configuration {
    security_groups = [aws_security_group.ecs.id]
    subnets         = [aws_subnet.private.id, aws_subnet.secondary.id]
  }

  lifecycle {
    ignore_changes = [
      platform_version,
    ]
  }

  depends_on = [
    aws_lb_listener.backend,
  ]
}

#ecs service, lb and task definitions
# Create a security group to allow traffic to/from the load balancer
# Define the frontend task definition
/*
resource "aws_ecs_task_definition" "frontend_task_definition" {
  family                   = "frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name            = "frontend-container"
      image           = "224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-frontend-app"
      essential       = true
      port_mappings   = [{
        container_port = 80
        host_port      = 0
      }]
      environment     = [
        {name = "DB_HOST", value = aws_rds_cluster_instance.db_instance.address},
        {name = "DB_PORT", value = "5432"},
        {name = "DB_NAME", value = "mydb"},
        {name = "DB_USER", value = "myuser"},
        {name = "DB_PASSWORD", value = "mypassword"},
      ]
      log_configuration {
        log_driver = "awslogs"
        options    = {
          "awslogs-group"         = "/ecs/frontend"
          "awslogs-region"        = "us-east-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Define the backend task definition
resource "aws_ecs_task_definition" "backend_task_definition" {
  family                   = "backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name            = "backend-container"
      image           = "224544193422.dkr.ecr.us-east-2.amazonaws.com/lfapp:my-backend-app"
      essential       = true
      port_mappings   = [{
        container_port = 8080
        host_port      = 0
      }]
      environment     = [
        {name = "DB_HOST", value = aws_rds_cluster_instance.db_instance.address},
        {name = "DB_PORT", value = "5432"},
        {name = "DB_NAME", value = "mydb"},
        {name = "DB_USER", value = "myuser"},
        {name = "DB_PASSWORD", value = "mypassword"},
      ]
      log_configuration {
        log_driver = "awslogs"
        options    = {
          "awslogs-group"         = "/ecs/backend"
          "awslogs-region"        = "us-east-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}


# Define the load balancer and target group
resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    var.public_subnet_id,
    var.private_subnet_id
  ]

  security_groups = [
    aws_security_group.ecs_lb_sg.id
  ]
}
*/