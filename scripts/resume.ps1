#Requires -Version 5
# EventBridge 스케줄을 다시 실행 (성적 확인 재개).
$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)

terraform apply -auto-approve -var schedule_state=ENABLED
if ($LASTEXITCODE -ne 0) { throw "terraform apply 실패" }
Write-Host "스케줄이 ENABLED 되었습니다."
