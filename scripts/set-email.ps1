#Requires -Version 5
# 알림 받을 이메일 주소를 terraform.tfvars 에 설정.
# 사용법: .\set-email.ps1 you@example.com   (인자 없으면 입력 받음)
param([string]$Email)
$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)

if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Read-Host "알림 받을 이메일 주소"
}

if ([string]::IsNullOrWhiteSpace($Email)) {
    Write-Error "이메일이 비어 있습니다."
    exit 1
}

# BOM 없이 작성 (terraform 호환)
[System.IO.File]::WriteAllText("$PWD\terraform.tfvars", "notification_email = `"$Email`"`n")
Write-Host "terraform.tfvars 설정됨: notification_email = `"$Email`""
