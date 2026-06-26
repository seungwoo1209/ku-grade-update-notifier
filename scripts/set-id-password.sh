#!/usr/bin/env bash
# 건국대 포털 로그인 ID/PW 를 SSM SecureString 파라미터에 저장.
#
# 주의: 파라미터는 먼저 존재해야 합니다 -> ./up.sh 를 한 번 실행한 뒤 사용하세요.
# main.tf 가 더미 값으로 파라미터를 생성하고 ignore_changes=[value] 로 두므로,
# 여기서 --overwrite 로 실제 값을 넣어도 terraform 이 되돌리지 않습니다.
set -euo pipefail

REGION="ap-northeast-2"
SID_PARAM="/grade-update-checker/student-id"
PWD_PARAM="/grade-update-checker/password"

read -rp "포털 ID: " SID
read -rsp "포털 PW: " PWD
echo

if [[ -z "$SID" || -z "$PWD" ]]; then
  echo "ID/PW 가 비어 있습니다." >&2
  exit 1
fi

aws ssm put-parameter --region "$REGION" \
  --name "$SID_PARAM" --type SecureString --overwrite --value "$SID" >/dev/null
aws ssm put-parameter --region "$REGION" \
  --name "$PWD_PARAM" --type SecureString --overwrite --value "$PWD" >/dev/null

echo "ID/PW 저장 완료."
