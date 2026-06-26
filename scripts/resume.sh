#!/usr/bin/env bash
# EventBridge 스케줄을 다시 실행 (성적 확인 재개).
set -euo pipefail

cd "$(dirname "$0")/.."

terraform apply -auto-approve -var schedule_state=ENABLED
echo "람다 함수 스케줄 활성화 완료."
