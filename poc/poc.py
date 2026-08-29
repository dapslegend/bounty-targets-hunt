#!/usr/bin/env python3
"""Placeholder WEB2 PoC runner entry. Agents replace this with a real proof.

Never DoS. Never hit out-of-scope hosts. Print raw evidence to stdout.
"""
from __future__ import annotations

import os
import sys


def main() -> int:
    target = os.environ.get("W2H_PRIMARY_URL", "")
    print("poc.py: no proof yet. Set W2H_PRIMARY_URL and implement the assigned sink.")
    if target:
        print(f"assigned={target}")
    print("FAIL")
    return 2


if __name__ == "__main__":
    sys.exit(main())
