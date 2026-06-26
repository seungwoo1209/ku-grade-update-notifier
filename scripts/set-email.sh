#!/usr/bin/env bash
# 알림 받을 이메일 주소를 terraform.tfvars 에 설정.
# 사용법: ./set-email.sh you@example.com   (인자 없으면 입력 받음)
set -euo pipefail

cd "$(dirname "$0")/.."

EMAIL="${1:-}"
if [[ -z "$EMAIL" ]]; then
  read -rp "알림 받을 이메일 주소: " EMAIL
fi

if [[ -z "$EMAIL" ]]; then
  echo "이메일이 비어 있습니다." >&2
  exit 1
fi

printf 'notification_email = "%s"\n' "$EMAIL" > terraform.tfvars
echo "terraform.tfvars 설정됨: notification_email = \"$EMAIL\""
