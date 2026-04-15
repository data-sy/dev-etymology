#!/usr/bin/env python3
"""
DevEtym 번들 DB 배치 생성 스크립트.

사용법:
    export ANTHROPIC_API_KEY=sk-ant-...
    python Scripts/generate_db.py \\
        --input DevEtym/DevEtym/Resources/terms.json \\
        --output DevEtym/DevEtym/Resources/terms.json \\
        --keywords Scripts/keywords.txt

동작:
    1) --keywords 파일에서 영문 소문자 keyword 목록을 읽는다
    2) --input 파일의 기존 용어는 그대로 보존한다 (keyword/aliases 변경 금지)
    3) 기존 목록에 없는 keyword만 Claude API에 배치 요청한다
    4) 응답을 검증한 뒤 --output에 저장한다

검증 규칙 (실패 시 비정상 종료):
    - 모든 용어에 aliases >= 1
    - 각 용어에 한글 표기 alias 최소 1개
    - keyword는 영문 소문자 + 하이픈/언더스코어만 허용
    - 모든 필드 비어있지 않음
    - category는 6개 고정 값 중 하나 ("동시성", "자료구조", "네트워크", "DB", "패턴", "기타")
    - keyword 중복 없음
    - 최종 JSON 유효성 (json.loads 통과)
    - 총 200개 이상
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

try:
    import urllib.request
    import urllib.error
except ImportError:  # pragma: no cover
    sys.exit("urllib is required")

CLAUDE_MODEL = "claude-sonnet-4-5-20250514"
API_URL = "https://api.anthropic.com/v1/messages"
API_VERSION = "2023-06-01"

SYSTEM_PROMPT = """당신은 개발 용어의 어원을 설명하는 사전 데이터 제공자입니다.
아래의 엄격한 JSON 배열 형식으로만 응답해야 하며, 마크다운(```)이나 부연 설명을 포함하지 마세요.

[응답 형식]
[
  {
    "keyword": "영문 소문자 (하이픈/언더스코어 허용)",
    "aliases": ["한글 표기 (필수, 최소 1개)", "풀네임 등"],
    "category": "동시성 | 자료구조 | 네트워크 | DB | 패턴 | 기타 중 하나",
    "summary": "한 줄 요약 (한국어)",
    "etymology": "어원 설명 (한국어)",
    "namingReason": "작명 이유 (한국어)"
  }
]

[엄격한 제한]
- 응답은 '['로 시작하고 ']'로 끝나야 합니다
- 각 용어에 한글 표기 alias를 반드시 1개 이상 포함합니다
- category는 다음 6개 값 중 하나여야 합니다: "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"
- 6개 분류에 애매하게 걸치는 경우 가장 핵심적인 분류를 선택하고, 어느 분류에도 명확히 속하지 않으면 "기타"를 사용하세요
- 어원이 불확실하면 "정확한 어원은 불분명하나"로 시작해 알려진 설만 서술합니다
- 추측이나 민간어원을 사실처럼 서술하지 마세요
- 약어는 각 글자가 무엇의 약자인지 명시하세요
"""

HANGUL_RE = re.compile(r"[\uac00-\ud7a3]")
KEYWORD_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
REQUIRED_FIELDS = ("keyword", "aliases", "category", "summary", "etymology", "namingReason")
ALLOWED_CATEGORIES = {"동시성", "자료구조", "네트워크", "DB", "패턴", "기타"}
MIN_TOTAL = 200


def load_existing(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def read_keywords(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    return [ln.strip() for ln in lines if ln.strip() and not ln.strip().startswith("#")]


def chunked(seq: list[str], size: int) -> list[list[str]]:
    return [seq[i:i + size] for i in range(0, len(seq), size)]


def call_claude(api_key: str, batch: list[str]) -> list[dict[str, Any]]:
    user_prompt = (
        "다음 개발 용어들의 어원 데이터를 JSON 배열로 반환하세요. "
        "keyword는 입력과 동일하게 쓰세요.\n\n"
        + "\n".join(f"- {k}" for k in batch)
    )
    body = json.dumps({
        "model": CLAUDE_MODEL,
        "max_tokens": 8192,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": user_prompt}],
    }).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={
            "x-api-key": api_key,
            "anthropic-version": API_VERSION,
            "content-type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    text = payload["content"][0]["text"].strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return json.loads(text)


def validate(terms: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for i, t in enumerate(terms):
        tag = f"[{i}] {t.get('keyword', '?')}"
        for f in REQUIRED_FIELDS:
            v = t.get(f)
            if v is None or (isinstance(v, str) and not v.strip()):
                errors.append(f"{tag}: '{f}' 비어있음")
            if f == "aliases" and (not isinstance(v, list) or len(v) < 1):
                errors.append(f"{tag}: aliases는 최소 1개 필요")
        kw = t.get("keyword", "")
        if kw in seen:
            errors.append(f"{tag}: keyword 중복")
        seen.add(kw)
        if not KEYWORD_RE.match(kw):
            errors.append(f"{tag}: keyword 형식 오류 (영문 소문자/숫자/하이픈/언더스코어만)")
        aliases = t.get("aliases") or []
        if not any(isinstance(a, str) and HANGUL_RE.search(a) for a in aliases):
            errors.append(f"{tag}: 한글 표기 alias 최소 1개 필요")
        category = t.get("category")
        if category not in ALLOWED_CATEGORIES:
            errors.append(
                f"{tag}: category '{category}' — 허용값 {sorted(ALLOWED_CATEGORIES)} 중 하나여야 함"
            )
    if len(terms) < MIN_TOTAL:
        errors.append(f"총 {len(terms)}개 — 최소 {MIN_TOTAL}개 필요")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--keywords", type=Path,
                        help="생성할 keyword 목록 파일 (없으면 검증만 수행)")
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--sleep", type=float, default=1.0,
                        help="배치 간 대기 (초)")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()

    existing = load_existing(args.input)
    existing_keys = {t["keyword"] for t in existing}
    merged: list[dict[str, Any]] = list(existing)

    if not args.validate_only and args.keywords:
        api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
        if not api_key:
            sys.exit("ANTHROPIC_API_KEY 환경변수가 비어있습니다")
        requested = read_keywords(args.keywords)
        pending = [k for k in requested if k not in existing_keys]
        print(f"기존 {len(existing)}개 + 신규 {len(pending)}개 요청")
        for batch in chunked(pending, args.batch_size):
            print(f"  배치 생성: {batch}")
            try:
                generated = call_claude(api_key, batch)
            except (urllib.error.URLError, json.JSONDecodeError, KeyError) as e:
                sys.exit(f"API 호출 실패: {e}")
            for t in generated:
                if t.get("keyword") in existing_keys:
                    continue
                merged.append(t)
                existing_keys.add(t["keyword"])
            time.sleep(args.sleep)

    errors = validate(merged)
    if errors:
        print("검증 실패:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    args.output.write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"저장 완료: {args.output} ({len(merged)}개)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
