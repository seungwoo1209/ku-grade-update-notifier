#Requires -Version 5
# EventBridge 스케줄을 멈춤 (성적 확인 일시 중지).
$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)

terraform apply -auto-approve -var schedule_state=DISABLED
if ($LASTEXITCODE -ne 0) { throw "terraform apply 실패" }
Write-Host "스케줄이 DISABLED 되었습니다."
