variable "region" {
  default = "us-west-2"
}

variable "app_name" {
  default = "app-runner-rds"
}

variable "ECR" {
  default = "108782064611.dkr.ecr.us-west-2.amazonaws.com/dhilipakaran/apprunner:latest"
}

variable "container_port" {
  default = "8080"
}

variable "cpu" {
  default = "1024"
}

variable "memory" {
  default = "2048"
}

variable "db_identifier" {
  default = "apprunnerdb"
}

variable "db_username" {
  default = "aws_user_postgres"
}

variable "db_password" {
  default = "awsdbtesting"
  sensitive = true
}

variable "db_name" {
  default = "mydb"
}