#!/usr/bin/env python3
"""Write /root/monad/bounty-targets-hunt/target/batch/<slug>/ for a pending program."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.environ.get("HUNT_ROOT", "/root/monad/bounty-targets-hunt"))
    ap.add_argument("--slug", required=True)
    args = ap.parse_args()
    root = Path(args.root)
    pending = root / "shared" / "queue" / "pending" / f"{args.slug}.json"
    archive = root / "shared" / "queue" / "archive" / f"{args.slug}.json"
    src = pending if pending.is_file() else archive
    if not src.is_file():
        print(f"missing candidate {args.slug}", file=sys.stderr)
        return 2
    c = load(src)
    dest = root / "target" / "batch" / args.slug
    dest.mkdir(parents=True, exist_ok=True)
    write(dest / "program.json", json.dumps(c, indent=2) + "\n")
    assets = c.get("assets") or []
    lines = ["url\thost\ttype\tmax_severity"]
    for a in assets:
        lines.append(
            "\t".join(
                [
                    str(a.get("url") or ""),
                    str(a.get("host") or ""),
                    str(a.get("type") or ""),
                    str(a.get("max_severity") or ""),
                ]
            )
        )
    write(dest / "in_scope.tsv", "\n".join(lines) + "\n")
    backups = []
    for a in assets[1:6]:
        u = a.get("url")
        if u:
            backups.append(f"- {u}")
    pin = f"""slug={c.get('slug')}
platform={c.get('platform')}
handle={c.get('handle')}
name={c.get('name')}
program_url={c.get('program_url')}
primary_url={c.get('primary_url')}
primary_host={c.get('primary_host')}
payout={c.get('payout')}
hunt_score={c.get('hunt_score')}
n_web={c.get('n_web')}
finding_id_prefix=W2H
"""
    write(dest / "PIN.txt", pin)
    scope = f"""# SCOPE — {c.get('name')} ({c.get('platform')}:{c.get('handle')})

Program policy: {c.get('program_url') or '(unknown — do not test until you have a policy URL)'}
Primary URL: {c.get('primary_url')}
Primary host: {c.get('primary_host')}

## In-scope web assets (from arkadiyt dump — policy wins)

"""
    for a in assets:
        scope += f"- `{a.get('url')}` type={a.get('type')} sev={a.get('max_severity')}\n"
        if a.get("instruction"):
            scope += f"  instruction: {a.get('instruction')}\n"
    scope += """
## Backups (same program only)

"""
    scope += ("\n".join(backups) + "\n") if backups else "(none)\n"
    scope += """
Stay on these hosts. Out-of-scope from the live policy is forbidden even if listed here.
Do not hunt `/work/target` (different campaign). Artifacts: `/work/bounty/...`.
"""
    write(dest / "SCOPE.md", scope)
    write(
        dest / "AUTHORIZATION.md",
        f"""# AUTHORIZATION — {c.get('handle')}

Public bug-bounty program. Read {c.get('program_url')} before testing.
Only in-scope assets. No DoS. No credential stuffing. No PII exfil.
finding_id W2H-xxx.
""",
    )
    # convenience copies at target/ for the current seed
    write(root / "target" / "PIN.txt", pin)
    write(root / "target" / "SCOPE.md", scope)
    write(root / "target" / "program.json", json.dumps(c, indent=2) + "\n")
    tsv = root / "target" / "BATCH.tsv"
    row = "\t".join(
        [
            str(c.get("slug")),
            str(c.get("platform")),
            str(c.get("handle")),
            str(c.get("primary_url")),
            str(c.get("payout")),
            str(c.get("hunt_score")),
        ]
    )
    prev = tsv.read_text(encoding="utf-8") if tsv.is_file() else "slug\tplatform\thandle\turl\tpayout\tscore\n"
    if str(c.get("slug")) not in prev:
        tsv.write_text(prev.rstrip("\n") + "\n" + row + "\n", encoding="utf-8")
    print(f"[materialize] {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
