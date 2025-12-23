############################
# provider.tf
############################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

############################
# var.tf
############################
variable "env" {
  type = string
}

variable "short_region" {
  type = string
}

variable "function_name" {
  type = string
}

variable "lambda_source_file" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type    = string
  default = "python3.11"
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

############################
# locals.tf
############################
locals {
  aws_provider = var.short_region == "east" ? aws.east : aws.west
}

############################
# main.tf
############################
module "lambda" {
  source = "./modules/lambda"

  providers = {
    aws = local.aws_provider
  }

  function_name      = var.function_name
  lambda_source_file = var.lambda_source_file
  handler            = var.handler
  runtime            = var.runtime
  env_vars           = var.env_vars
}

############################
# modules/lambda/var.tf
############################
variable "function_name" {
  type = string
}

variable "lambda_source_file" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
}

variable "env_vars" {
  type = map(string)
}

############################
# modules/lambda/main.tf
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "lambda" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = var.handler
  runtime       = var.runtime

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = var.env_vars
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}

############################
# dev east example
############################
# terraform plan \
# -var="env=dev" \
# -var="short_region=east" \
# -var="function_name=test-east" \
# -var="lambda_source_file=./lambda_source_code/test.py" \
# -var="handler=test.lambda_handler"

############################
# dev west example
############################
# terraform plan \
# -var="env=dev" \
# -var="short_region=west" \
# -var="function_name=test-west" \
# -var="lambda_source_file=./lambda_source_code/test.py" \
# -var="handler=test.lambda_handler"
