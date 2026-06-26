#!/usr/bin/env bash
# EventBridge 스케줄을 멈춤 (성적 확인 일시 중지).
set -euo pipefail

cd "$(dirname "$0")/.."

terraform apply -auto-approve -var schedule_state=DISABLED
echo "람다 함수 스케줄이 비활성화되었습니다."
