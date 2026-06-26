#!/usr/bin/env bash
# 인프라 전체 정리 (terraform destroy).
set -euo pipefail

cd "$(dirname "$0")/.."

terraform destroy
