terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = "ap-northeast-2"
}

# ====== sns topic & email subscription ======
# terraform apply 후 대상 메일함에서 aws 이메일 수신을 완료해야 실제 이메일이 발송됨

resource "aws_sns_topic" "grade-update-topic" {
  name = "grade-update-topic"
}

variable "notification_email" {
  description = "성적 변동 알림 받을 이메일 주소"
  type        = string
}

resource "aws_sns_topic_subscription" "email-subcription" {
  topic_arn = aws_sns_topic.grade-update-topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ====== lambda function(check grade, publish changes to SNS topic) ======

data "archive_file" "lambda_zip" {
  type        = "zip" # terraform 내에서 압축 수행, apply 시 변경 내용 감지하면 새로 압축 수행
  output_path = "${path.module}/lambda_function.zip"
  source_file = "${path.module}/lambda/grade-checker.py"
}

resource "aws_lambda_function" "grade-update-checker-lambda" {
  function_name    = "grade-update-checker-lambda"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "grade-checker.lambda_handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.grade-update-topic.arn
    }
  }

  tags = {
    Project = "ku-grade-update-notifier"
  }
}

# ====== eventbridge scheduler(invokes lambda every 5 minutes) ======
variable "schedule_state" {
  description = "EventBridge 스케줄 상태 (ENABLED/DISABLED). stop.sh/resume.sh가 토글함"
  type        = string
  default     = "ENABLED"
}

resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.grade-update-checker-lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.grade-update-checker-schedule.arn
}

resource "aws_scheduler_schedule" "grade-update-checker-schedule" {
  name       = "trigger-checker-lambda"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(5 minutes)"
  state               = var.schedule_state

  target {
    arn      = aws_lambda_function.grade-update-checker-lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }
}

# ====== SSM parameter store (account id, password, current state, cookie, flag) ======

# 1. 건국대학교 포털 ID (SecureString)
resource "aws_ssm_parameter" "student_id" {
  name        = "/grade-update-checker/student-id"
  description = "로그인 ID"
  type        = "SecureString"
  value       = "dummy-student-id" # 보안을 위해 실제 값은 AWS 콘솔/CLI에서 직접 업데이트

  lifecycle {
    ignore_changes = [value]
  }
}

# 2. 건국대학교 포털 PW (SecureString)
resource "aws_ssm_parameter" "password" {
  name        = "/grade-update-checker/password"
  description = "로그인 PW"
  type        = "SecureString"
  value       = "dummy-password" # 보안을 위해 실제 값은 AWS 콘솔/CLI에서 직접 업데이트

  lifecycle {
    ignore_changes = [value]
  }
}

# 3. 로그인 쿠키(String)
resource "aws_ssm_parameter" "cookie" {
  name  = "/grade-update-checker/cookie"
  type  = "String"
  value = " " # 공백 필요(빈 값 넣을 시 실패)
  lifecycle {
    ignore_changes = [value]
  }
}

# 4. 마지막 성적 상태 (String)
resource "aws_ssm_parameter" "last_state" {
  name  = "/grade-update-checker/last-state"
  type  = "String"
  value = "{}"
  lifecycle {
    ignore_changes = [value]
  }
}

# 5. 중복 실패 알림 방지용 플래그 (String)
resource "aws_ssm_parameter" "alert_flag" {
  name  = "/grade-update-checker/alert-flag"
  type  = "String"
  value = "ok"
  lifecycle {
    ignore_changes = [value]
  }
}