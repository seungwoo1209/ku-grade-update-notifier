"""
성적 입력 감시 Lambda (EventBridge Scheduler가 1분마다 호출) - 자동 재로그인 버전

흐름:
  1) SSM에 저장된 쿠키로 성적 조회 시도
  2) 세션 만료(JSON 아님 등)면 -> 자동 재로그인:
       GET /index.do 로 익명 세션 쿠키 발급
       POST /Login/login.do (아이디/비번) 로 로그인된 쿠키 확보
       새 쿠키를 SSM에 저장하고 성적 조회 재시도
  3) 그래도 실패하면(아이디/비번 문제 등) "재로그인 실패" 알림 1회
  4) 정상 데이터면 HAKSU_ID 기준 성적 변화 비교 -> 변동 시 SNS publish
  5) 새 상태 저장

SSM Parameter Store:
  - /grade-update-checker/cookie       : 현재 쿠키 헤더 (자동 갱신됨, String)
  - /grade-update-checker/student-id   : 로그인 아이디 (SecureString 권장)
  - /grade-update-checker/password     : 로그인 비번  (SecureString 권장)
  - /grade-update-checker/last-state   : 직전 성적 축약 맵 (JSON, String)
  - /grade-update-checker/alert-flag   : 재로그인 실패 알림 플래그 (String)
"""

import json
import os
import http.cookies
import urllib.request
import urllib.error

import boto3

# ---- 설정 ----
TOPIC_ARN     = os.environ["SNS_TOPIC_ARN"]
COOKIE_PARAM  = os.environ.get("COOKIE_PARAM",  "/grade-update-checker/cookie")
SID_PARAM     = os.environ.get("SID_PARAM",     "/grade-update-checker/student-id")
PWD_PARAM     = os.environ.get("PWD_PARAM",     "/grade-update-checker/password")
STATE_PARAM   = os.environ.get("STATE_PARAM",   "/grade-update-checker/last-state")
ALERT_PARAM   = os.environ.get("ALERT_PARAM",   "/grade-update-checker/alert-flag")

BASE = "https://kuis.konkuk.ac.kr"
INDEX_URL = f"{BASE}/index.do"
LOGIN_URL = f"{BASE}/Login/login.do"
GRADE_URL = f"{BASE}/GradNowShtmGradeInq/find.do"

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36")

# 성적 조회 body (난독화 파라미터 고정값)
GRADE_BODY = (
    "Oe2Ue=%239e4ki&Le093=e%26*%08iu&AWeh_3=W%5E_zie&Hd%2Cpoi=_qw3e4"
    "&EKf8_%2F=Ajd%25md&WEh3m=ekmf3&rE%0Cje=JDow871&JKGhe8=NuMoe6"
    "&_)e7me=ne%2B3%7Cq&3kd3Nj=Qnd%40%251&_AUTH_MENU_KEY=1140302"
    "&%40d1%23curDate=20260624&%40d1%23basiYy=2026&%40d1%23basiShtm=B01011"
    "&%40d1%23stdNo=202111283&%40d%23=%40d1%23&%40d1%23=dmParam&%40d1%23tp=dm&"
)

# 로그인 body. 앞쪽 난독화 파라미터는 고정값, 아이디/비번만 런타임 주입.
# {SID}, {PWD} 자리에 SSM 값이 들어간다. (값은 urlencode)
LOGIN_BODY_TMPL = (
    "Oe2Ue=%239e4ki&Le093=e%26*%08iu&AWeh_3=W%5E_zie&Hd%2Cpoi=_qw3e4"
    "&EKf8_%2F=Ajd%25md&WEh3m=ekmf3&rE%0Cje=JDow871&JKGhe8=NuMoe6"
    "&_)e7me=ne%2B3%7Cq&3kd3Nj=Qnd%40%251"
    "&%40d1%23SINGLE_ID={SID}&%40d1%23PWD={PWD}"
    "&%40d1%23default.locale=ko&%40d%23=%40d1%23&%40d1%23=dsParam&%40d1%23tp=dm&"
)
# --------------

ssm = boto3.client("ssm")
sns = boto3.client("sns")


# ---------- SSM ----------
def get_param(name, default=None, decrypt=False):
    try:
        return ssm.get_parameter(Name=name, WithDecryption=decrypt)["Parameter"]["Value"]
    except ssm.exceptions.ParameterNotFound:
        return default


def put_param(name, value):
    ssm.put_parameter(Name=name, Value=value, Type="String", Overwrite=True)


# ---------- HTTP ----------
def _request(url, *, method="GET", data=None, cookie=None):
    """(상태코드, 본문문자열, Set-Cookie리스트) 반환."""
    headers = {
        "User-Agent": UA,
        "Accept": "*/*",
        "Referer": INDEX_URL,
        "Origin": BASE,
        "X-Requested-With": "XMLHttpRequest",
    }
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    if cookie:
        headers["Cookie"] = cookie

    req = urllib.request.Request(
        url, data=data.encode() if data else None, method=method, headers=headers
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8", "replace")
            set_cookies = resp.headers.get_all("Set-Cookie") or []
            return resp.status, body, set_cookies
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        set_cookies = e.headers.get_all("Set-Cookie") or []
        return e.code, body, set_cookies
    except urllib.error.URLError as e:
        raise RuntimeError(f"네트워크 오류: {e}")


def _merge_cookies(base_cookie: str, set_cookie_headers: list) -> str:
    """기존 쿠키 + 응답 Set-Cookie 병합 -> 'k=v; k=v' 헤더 문자열."""
    jar = {}
    if base_cookie:
        for part in base_cookie.split(";"):
            if "=" in part:
                k, v = part.strip().split("=", 1)
                jar[k] = v
    for line in set_cookie_headers:
        c = http.cookies.SimpleCookie()
        c.load(line)
        for k, morsel in c.items():
            jar[k] = morsel.value
    return "; ".join(f"{k}={v}" for k, v in jar.items())


# ---------- 도메인 로직 ----------
class SessionExpired(Exception):
    pass


def parse_grades(body: str) -> list:
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise SessionExpired("JSON 아님(로그인 페이지 추정)")
    rows = data.get("DS_GRADEOFSTUDENT")
    if not isinstance(rows, list):
        raise SessionExpired("DS_GRADEOFSTUDENT 없음")
    return rows


def query_grades(cookie: str) -> list:
    status, body, _ = _request(GRADE_URL, method="POST", data=GRADE_BODY, cookie=cookie)
    return parse_grades(body)


def relogin() -> str:
    """전체 로그인 절차를 밟아 로그인된 쿠키 헤더를 반환."""
    sid = get_param(SID_PARAM, decrypt=True)
    pwd = get_param(PWD_PARAM, decrypt=True)
    if not sid or not pwd:
        raise RuntimeError("아이디/비번 파라미터 없음")

    # 1) 익명 세션 발급
    _, _, sc1 = _request(INDEX_URL, method="GET")
    cookie = _merge_cookies("", sc1)

    # 2) 로그인 -> 보통 여기서 JSESSIONID가 교체됨
    body = LOGIN_BODY_TMPL.format(
        SID=urllib.parse.quote(sid, safe=""), # type: ignore
        PWD=urllib.parse.quote(pwd, safe=""), # type: ignore
    )
    _, _, sc2 = _request(LOGIN_URL, method="POST", data=body, cookie=cookie)
    cookie = _merge_cookies(cookie, sc2)  # 교체된 쿠키 반영

    return cookie


def publish(msg: str):
    sns.publish(TopicArn=TOPIC_ARN, Message=msg)
    print("published:", msg)


# ---------- 비교 ----------
def to_state(rows):
    return {r["HAKSU_ID"]: {"grd": r.get("CALCU_GRD"),
                            "nm":  r.get("TYPL_KOR_NM")} for r in rows}


def diff(old, new):
    out = []
    for hid, cur in new.items():
        prev = old.get(hid, {})
        if cur["grd"] != prev.get("grd"):
            out.append({"nm": cur["nm"], "old": prev.get("grd"),
                        "new": cur["grd"]})
    return out


def build_message(changes):
    lines = ["[성적 변동]"]
    for c in changes:
        o = c["old"] if c["old"] is not None else "-"
        n = c["new"] if c["new"] is not None else "-"
        lines.append(f"- {c['nm']}: {o}→{n}")
    return "\n".join(lines)


# ---------- 핸들러 ----------
def lambda_handler(event, context):
    cookie = get_param(COOKIE_PARAM, "")

    # 1차 시도 -> 만료면 재로그인 후 2차 시도
    try:
        rows = query_grades(cookie)
    except SessionExpired:
        print("session expired -> relogin")
        try:
            cookie = relogin()
            put_param(COOKIE_PARAM, cookie)
            rows = query_grades(cookie)   # 재시도
        except (SessionExpired, RuntimeError) as e:
            # 재로그인 자체가 실패 = 비번 변경/포털 점검 등 사람 개입 필요
            if get_param(ALERT_PARAM) != "sent":
                publish("[성적봇] 자동 재로그인 실패. 아이디/비번/포털 상태 확인 필요.")
                put_param(ALERT_PARAM, "sent")
            print("relogin failed:", e)
            return {"status": "relogin_failed"}

    # 정상 -> 실패 플래그 해제
    if get_param(ALERT_PARAM) == "sent":
        put_param(ALERT_PARAM, "ok")

    new_state = to_state(rows)
    old_state = json.loads(get_param(STATE_PARAM, "{}"))

    changes = diff(old_state, new_state)
    if changes:
        publish(build_message(changes))
    else:
        print("no change")

    put_param(STATE_PARAM, json.dumps(new_state, ensure_ascii=False))
    return {"status": "ok", "changed": len(changes)}