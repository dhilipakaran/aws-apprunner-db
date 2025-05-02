provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-allow-apprunner"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with allowlisted IPs or use App Runner's VPC CIDRs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "app_db" {
  identifier               = var.db_identifier
  engine                   = "postgres"
  instance_class           = "db.t3.micro"
  allocated_storage        = 20
  username                 = var.db_username
  password                 = var.db_password
  db_name                  = var.db_name
  publicly_accessible      = true
  skip_final_snapshot      = true
  delete_automated_backups = true

  vpc_security_group_ids   = [aws_security_group.rds_sg.id]
}

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.app_name}-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_apprunner_vpc_connector" "app_vpc_connector" {
  vpc_connector_name = "${var.app_name}-vpc-connector"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.rds_sg.id]
}

resource "aws_apprunner_service" "app_service" {
  service_name = var.app_name

  source_configuration {
    image_repository {
      image_identifier      = var.ECR
      image_repository_type = "ECR"
      image_configuration {
        port = var.container_port
        runtime_environment_variables = {
          DB_HOST     = aws_db_instance.app_db.address
          DB_PORT     = aws_db_instance.app_db.port
          DB_NAME     = aws_db_instance.app_db.db_name
          DB_USER     = aws_db_instance.app_db.username
          DB_PASSWORD = var.db_password
        }
      }
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    auto_deployments_enabled = true
  }

  instance_configuration {
    cpu    = var.cpu
    memory = var.memory
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.app_vpc_connector.arn
    }
  }
}
