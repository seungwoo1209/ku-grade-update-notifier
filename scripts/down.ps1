#Requires -Version 5
# 인프라 전체 정리 (terraform destroy).
$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)

terraform destroy
if ($LASTEXITCODE -ne 0) { throw "terraform destroy 실패" }
