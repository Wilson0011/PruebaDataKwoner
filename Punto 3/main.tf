# Configurar el proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Variables de configuración
variable "bucket_name" {
  type = string
  default = "s3-to-dynamodb-bucket"
}

variable "table_name" {
  type = string
  default = "datos_procesados"
}

# Crear un bucket de S3
resource "aws_s3_bucket" "data_bucket" {
  bucket = var.bucket_name
  acl    = "private"

  force_destroy = true
}

# Crear una tabla de DynamoDB
resource "aws_dynamodb_table" "data_table" {
  name = var.table_name
  hash_key = "id" # Reemplazar con la clave hash real de su esquema

  # Definir el esquema de la tabla
  attribute {
    name = "id"
    type = "S"
  }

  # Agregar más atributos según el esquema del archivo plano

  billing_mode = "PAY_PER_REQUEST"
}

# Crear un rol IAM para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_s3_trigger_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# Asignar permisos al rol de Lambda para acceder a S3 y Glue
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_s3_glue_policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "glue:StartJobRun"
      ],
      "Resource": [
        "${aws_s3_bucket.data_bucket.arn}",
        "${aws_s3_bucket.data_bucket.arn}/*",
        "arn:aws:glue:*:*:job/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Crear la función Lambda
resource "aws_lambda_function" "s3_trigger_lambda" {
  function_name    = "s3_trigger_glue_job"
  handler = "index.handler" # Reemplazar con el controlador de su función Lambda
  runtime = "nodejs14.x" # Reemplazar con el tiempo de ejecución deseado

  role = aws_iam_role.lambda_role.arn

  # Subir el código de la función Lambda
  s3_bucket = "your-lambda-code-bucket" # Reemplazar con el nombre de su bucket
  s3_key    = "lambda_function.zip" # Reemplazar con la clave de su archivo ZIP

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.data_processing_job.name
    }
  }
}

# Configurar la notificación de S3 para activar la función Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger_lambda.arn
    events = ["s3:ObjectCreated:Put"]
    filter_prefix = "input/" # Activar solo para archivos en la carpeta "input"
  }
}

# Crear un rol IAM para el trabajo de Glue
resource "aws_iam_role" "glue_job_role" {
  name = "glue_job_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# Asignar permisos al rol de Glue para acceder a S3 y DynamoDB
resource "aws_iam_policy" "glue_job_policy" {
  name = "glue_job_s3_dynamodb_policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "dynamodb:BatchWriteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": [
        "${aws_s3_bucket.data_bucket.arn}",
        "${aws_s3_bucket.data_bucket.arn}/*",
        "${aws_dynamodb_table.data_table.arn}"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "glue_job_policy_attachment" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = aws_iam_policy.glue_job_policy.arn
}

# Crear el trabajo de Glue
resource "aws_glue_job" "data_processing_job" {
  name = "s3_to_dynamodb_job"
  role_arn = aws_iam_role.glue_job_role.arn

  # Configurar el trabajo de Glue (reemplazar con su script de Glue)
  command {
    name            = "glueetl"
    script_location = "s3://your-glue-scripts-bucket/glue_script.py" # Reemplazar con la ubicación de su script de Glue
  }
}