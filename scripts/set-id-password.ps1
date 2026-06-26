#Requires -Version 5
# 건국대 포털 로그인 ID/PW 를 SSM SecureString 파라미터에 저장.
#
# 주의: 파라미터는 먼저 존재해야 합니다 -> .\up.ps1 을 한 번 실행한 뒤 사용하세요.
# main.tf 가 더미 값으로 파라미터를 생성하고 ignore_changes=[value] 로 두므로,
# 여기서 --overwrite 로 실제 값을 넣어도 terraform 이 되돌리지 않습니다.
$ErrorActionPreference = 'Stop'

$Region   = "ap-northeast-2"
$SidParam = "/grade-update-checker/student-id"
$PwdParam = "/grade-update-checker/password"

$Sid = Read-Host "포털 ID"
$SecurePwd = Read-Host "포털 PW" -AsSecureString

# aws CLI 전달용으로만 평문 변환 (메모리 내)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePwd)
try {
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrWhiteSpace($Sid) -or [string]::IsNullOrWhiteSpace($Password)) {
    Write-Error "ID/PW 가 비어 있습니다."
    exit 1
}

aws ssm put-parameter --region $Region --name $SidParam --type SecureString --overwrite --value $Sid | Out-Null
if ($LASTEXITCODE -ne 0) { throw "student-id 저장 실패" }
aws ssm put-parameter --region $Region --name $PwdParam --type SecureString --overwrite --value $Password | Out-Null
if ($LASTEXITCODE -ne 0) { throw "password 저장 실패" }

Write-Host "ID/PW 가 SSM 에 저장되었습니다."
