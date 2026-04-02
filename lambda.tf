#1. Lambda Security Group (Step 1)
resource "aws_security_group" "lambda_sg" {
  name        = "${local.name_prefix}-moviesdb-api-sg"
  description = "Lambda SG to access RDS"
  vpc_id      = module.vpc.vpc_id

  # No ingress needed (Lambda is not receiving traffic)

  egress {
    description     = "Allow MySQL to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.security_group.security_group_id]
  }

  tags = local.tags
}

#2. IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

#Attach policies:
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

#4. Lambda Package (Step 3)
resource "aws_lambda_function" "movies_api" {
  function_name = "${local.name_prefix}-moviesdb-api"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  timeout = 10

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_NAME      = "sandboxdb"
      USERNAME     = "admin"
      PASSWORD     = "replace-me" # better: Secrets Manager
      RDS_ENDPOINT = module.db.db_instance_endpoint
    }
  }

  tags = local.tags
}

output "lambda_name" {
  value = aws_lambda_function.movies_api.function_name
}