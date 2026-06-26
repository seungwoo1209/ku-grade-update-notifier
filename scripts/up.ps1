#Requires -Version 5
# 인프라 생성/갱신 (terraform apply).
$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)

terraform init -input=false
if ($LASTEXITCODE -ne 0) { throw "terraform init 실패" }
terraform apply
if ($LASTEXITCODE -ne 0) { throw "terraform apply 실패" }

Write-Host ""
Write-Host "참고: 최초 apply 후 받은 메일함에서 AWS SNS 구독 확인 메일을 승인해야"
Write-Host "      실제 알림 이메일이 발송됩니다."
Write-Host "다음 단계: .\scripts\set-id-password.ps1 로 포털 ID/PW 를 설정하세요."
