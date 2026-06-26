# ====== Lambda ======
resource "aws_iam_role" "lambda_exec_role" {
  name = "grade-update-checker-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# CloudWatch Logs 기본 권한 (관리형 정책)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_kms_key" "ssm" {
  key_id     = "alias/aws/ssm"
  depends_on = [aws_ssm_parameter.password]
}

resource "aws_iam_role_policy" "lambda_app" {
  name = "grade-checker-app-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SsmReadWrite"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = [
          aws_ssm_parameter.student_id.arn,
          aws_ssm_parameter.password.arn,
          aws_ssm_parameter.cookie.arn,
          aws_ssm_parameter.last_state.arn,
          aws_ssm_parameter.alert_flag.arn,
        ]
      },
      {
        Sid      = "KmsDecryptForSecureString"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = data.aws_kms_key.ssm.arn
      },
      {
        Sid      = "SnsPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.grade-update-topic.arn
      }
    ]
  })
}


# ====== Eventbridge Scheduler ======
resource "aws_iam_role" "scheduler_role" {
  name = "grade-update-checker-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  role = aws_iam_role.scheduler_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.grade-update-checker-lambda.arn
    }]
  })
}