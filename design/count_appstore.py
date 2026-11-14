#!/usr/bin/env python3
"""AppStore.md 안의 코드 블록 글자 수를 App Store Connect 제한과 비교한다.
실행: python3 design/count_appstore.py
"""
import re
from pathlib import Path

LIMITS = {
    "이름": 30, "부제": 30, "홍보 문구": 170, "키워드": 100, "설명": 4000, "새로운 기능": 4000,
    "Name": 30, "Subtitle": 30, "Promotional Text": 170, "Keywords": 100, "Description": 4000, "What's New": 4000,
}

text = Path(__file__).resolve().parents[1].joinpath("AppStore.md").read_text(encoding="utf-8")
ok = True
for heading, body in re.findall(r"^### (.+?)\n(?:>.*\n)*```\n(.*?)\n```", text, flags=re.M | re.S):
    name = re.sub(r"\s*\(.*", "", heading).strip()
    name = re.sub(r"\s*—.*", "", name).strip()
    limit = LIMITS.get(name)
    if limit is None:
        continue
    n = len(body)
    flag = "OK " if n <= limit else "OVER"
    ok &= n <= limit
    print(f"{flag} {name:18s} {n:5d} / {limit}")
print("모두 제한 안" if ok else "제한을 넘은 항목이 있어요")
