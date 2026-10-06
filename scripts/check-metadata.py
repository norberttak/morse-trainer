#!/usr/bin/env python3
"""Checks App Store text fields in docs/app-store/metadata.md against Apple's limits."""
import re
import sys
from pathlib import Path

LIMITS = {"promotional": 170, "description": 4000, "keywords": 100, "whatsnew": 4000, "reviewnotes": 4000}
TABLE_LIMITS = {"Name (≤ 30)": 30, "Subtitle (≤ 30)": 30}

text = Path(__file__).resolve().parent.parent.joinpath("docs/app-store/metadata.md").read_text()
ok = True

for key, limit in LIMITS.items():
    match = re.search(rf"<!-- {key} -->\n(.*?)\n<!-- /{key} -->", text, re.S)
    if not match:
        print(f"missing field: {key}")
        ok = False
        continue
    value = match.group(1)
    status = "ok" if len(value) <= limit else "TOO LONG"
    ok &= len(value) <= limit
    print(f"{key:12} {len(value):5} / {limit:<5} {status}")
    if key == "keywords" and any(not k.strip() for k in value.split(",")):
        print("keywords: empty entry")
        ok = False

for label, limit in TABLE_LIMITS.items():
    match = re.search(rf"\| {re.escape(label)} \| (.*?) \|", text)
    value = match.group(1) if match else ""
    status = "ok" if 0 < len(value) <= limit else "BAD"
    ok &= 0 < len(value) <= limit
    print(f"{label:18} {len(value):3} / {limit:<3} {status}  ({value})")

sys.exit(0 if ok else 1)
