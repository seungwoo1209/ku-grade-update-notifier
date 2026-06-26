#Requires -Version 5
# 이 프로젝트에 필요한 AWS CLI / Terraform 설치 (Windows / winget)
# 이미 설치되어 있으면 건너뜀. (choco를 쓴다면 winget 명령을 choco install로 대체)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget이 필요합니다. Windows 10/11의 '앱 설치 관리자'를 설치하거나 업데이트하세요."
    exit 1
}

if (Get-Command terraform -ErrorAction SilentlyContinue) {
    Write-Host "terraform 이미 설치됨, 건너뜀."
} else {
    Write-Host "terraform 설치 중..."
    winget install --id Hashicorp.Terraform --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "terraform 설치 실패" }
}

if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-Host "aws CLI 이미 설치됨, 건너뜀."
} else {
    Write-Host "aws CLI 설치 중..."
    winget install --id Amazon.AWSCLI --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "aws CLI 설치 실패" }
}

Write-Host ""
Write-Host "설치 완료:"
Write-Host "새로 설치한 경우 PATH 반영을 위해 새 터미널을 여세요."
terraform version
aws --version
