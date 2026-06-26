#!/usr/bin/env bash
# 이 프로젝트에 필요한 AWS CLI / Terraform 설치 (macOS / Homebrew)
# 이미 설치되어 있으면 건너뜀.
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew가 필요합니다. 먼저 설치하세요:" >&2
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  exit 1
fi

if command -v terraform >/dev/null 2>&1; then
  echo "terraform 이미 설치됨, 건너뜀."
else
  echo "terraform 설치 중..."
  brew install terraform
fi

if command -v aws >/dev/null 2>&1; then
  echo "aws CLI 이미 설치됨, 건너뜀."
else
  echo "aws CLI 설치 중..."
  brew install awscli
fi

echo
terraform version
aws --version

echo "[설치 완료]"
