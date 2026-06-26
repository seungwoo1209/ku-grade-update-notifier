#!/usr/bin/env bash
# 인프라 생성/갱신 (terraform apply).
set -euo pipefail

cd "$(dirname "$0")/.."

terraform init -input=false
terraform apply

echo
echo "참고: 최초 apply 후 받은 메일함에서 AWS SNS 구독 확인 메일을 승인해야"
echo "      실제 알림 이메일이 발송됩니다."
echo "다음 단계: ./set-id-password.sh 로 포털 ID/PW 를 설정하세요."
