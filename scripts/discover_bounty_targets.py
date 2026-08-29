#!/usr/bin/env python3
"""Pull arkadiyt/bounty-targets-data and rank unpopular in-scope WEB assets.

Writes pending JSON for seeding and archives every qualifying web asset.
Never prints secrets. Never broadcasts.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from urllib.parse import urlparse

FEED_REPO = os.environ.get(
    "BOUNTY_FEED_REPO", "https://github.com/arkadiyt/bounty-targets-data.git"
)
MAX_CANDIDATES = int(os.environ.get("MAX_CANDIDATES", "80"))
MAX_ARCHIVE_WRITE = int(os.environ.get("MAX_ARCHIVE_WRITE", "600"))
HUNT_PAYOUT_MIN = float(os.environ.get("HUNT_PAYOUT_MIN", "500"))
HUNT_PAYOUT_MAX = float(os.environ.get("HUNT_PAYOUT_MAX", "50000"))
MIN_SCORE = float(os.environ.get("MIN_SCORE", "20"))

WEB_TYPES = {
    "url",
    "website",
    "web",
    "web-application",
    "web_application",
    "api",
    "wildcard",
    "domain",
}
SKIP_TYPES = {
    "google_play_app_id",
    "apple_store_app_id",
    "windows_app_store_app_id",
    "other_apk",
    "other_ipa",
    "hardware",
    "iot",
    "smart_contract",
    "source_code",
    "downloadable_executables",
    "ai_model",
    "testflight",
    "android",
    "ios",
    "cidr",
    "ip_address",
    "network",
}

MEGA_NEEDLES = (
    "google vrp",
    "google-vrp",
    "facebook",
    "meta bug",
    "instagram",
    "whatsapp",
    "apple security",
    "microsoft",
    "xbox",
    "playstation",
    "amazon vrp",
    "aws vulnerability",
)


def norm(s: str) -> str:
    return (s or "").strip().lower()


def slugify(platform: str, handle: str) -> str:
    raw = f"{platform}-{handle}".lower()
    raw = re.sub(r"[^a-z0-9._-]+", "-", raw)
    return raw.strip("-")[:80] or "unknown"


def load_deny(path: Path) -> Tuple[Set[str], List[str]]:
    keys: Set[str] = set()
    needles: List[str] = []
    if not path.is_file():
        return keys, needles
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.split("#")[0].strip().lower()
        if not line:
            continue
        if line.startswith("needle:"):
            needles.append(line.split(":", 1)[1].strip())
        else:
            keys.add(line)
    return keys, needles


def is_denied(platform: str, handle: str, name: str, keys: Set[str], needles: List[str]) -> bool:
    blob = f"{platform}:{handle}"
    if blob in keys or handle in keys:
        return True
    n = f"{handle} {name}".lower()
    for nd in needles + list(MEGA_NEEDLES):
        if nd and nd in n:
            return True
    return False


def looks_like_host_or_url(identifier: str) -> bool:
    s = identifier.strip()
    if not s or " " in s:
        return False
    if any(ch in s for ch in "()|[]{}"):
        return False
    if s.startswith("http://") or s.startswith("https://") or s.startswith("*."):
        return True
    if "/" in s and "." in s.split("/")[0]:
        return True
    host = s.split("/")[0]
    return "." in host and not host.startswith(".")


def looks_web(asset_type: str, identifier: str) -> bool:
    t = norm(asset_type)
    ident = identifier.strip()
    if t in SKIP_TYPES:
        return False
    if not looks_like_host_or_url(ident):
        return False
    if t in WEB_TYPES or t in ("other", ""):
        return True
    return False


def host_of(identifier: str) -> str:
    s = identifier.strip()
    if s.startswith("*."):
        return s[2:].split("/")[0].lower()
    if "://" not in s:
        s = "https://" + s.lstrip("/")
    try:
        p = urlparse(s)
        return (p.hostname or "").lower()
    except Exception:
        return identifier.lower()[:80]


def primary_url(identifier: str) -> str:
    s = identifier.strip()
    if s.startswith("*."):
        return "https://" + s[2:].split("/")[0]
    if s.startswith("http://") or s.startswith("https://"):
        return s.split()[0]
    if "/" in s or "." in s:
        return "https://" + s.lstrip("/")
    return s


def payout_value(prog: dict) -> float:
    for k in ("max_payout", "max_bounty"):
        v = prog.get(k)
        if isinstance(v, (int, float)):
            return float(v)
        if isinstance(v, dict) and v.get("value") is not None:
            try:
                return float(v["value"])
            except (TypeError, ValueError):
                pass
        if isinstance(v, str):
            m = re.search(r"[\d.]+", v.replace(",", ""))
            if m:
                return float(m.group(0))
    return 0.0


def min_payout_value(prog: dict) -> float:
    v = prog.get("min_bounty") or prog.get("min_payout")
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, dict) and v.get("value") is not None:
        try:
            return float(v["value"])
        except (TypeError, ValueError):
            return 0.0
    return 0.0


def git_sync(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if (dest / ".git").is_dir():
        subprocess.run(
            ["git", "-C", str(dest), "pull", "--ff-only"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=120,
        )
        return
    subprocess.run(
        ["git", "clone", "--depth", "1", FEED_REPO, str(dest)],
        check=True,
        timeout=180,
    )


def iter_programs(data_dir: Path) -> List[dict]:
    out: List[dict] = []
    mapping = [
        ("hackerone", "hackerone_data.json"),
        ("bugcrowd", "bugcrowd_data.json"),
        ("intigriti", "intigriti_data.json"),
        ("yeswehack", "yeswehack_data.json"),
        ("federacy", "federacy_data.json"),
    ]
    for platform, fname in mapping:
        path = data_dir / fname
        if not path.is_file():
            continue
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"[discover] WARN {fname}: {e}", file=sys.stderr)
            continue
        if not isinstance(rows, list):
            continue
        for row in rows:
            if isinstance(row, dict):
                row = dict(row)
                row["_platform"] = platform
                out.append(row)
    return out


def in_scope_assets(prog: dict) -> List[dict]:
    t = prog.get("targets") or {}
    if isinstance(t, dict):
        ins = t.get("in_scope") or []
    elif isinstance(t, list):
        ins = t
    else:
        ins = []
    return [a for a in ins if isinstance(a, dict)]


def asset_id(a: dict) -> str:
    for k in ("asset_identifier", "endpoint", "target", "uri", "name"):
        v = a.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def asset_type(a: dict) -> str:
    return str(a.get("asset_type") or a.get("type") or a.get("category") or "")


def eligible(a: dict) -> bool:
    if a.get("eligible_for_submission") is False:
        return False
    if a.get("eligible_for_bounty") is False:
        return False
    return True


def hunt_score(c: dict) -> float:
    s = 0.0
    pay = float(c.get("payout") or 0)
    nweb = int(c.get("n_web") or 0)
    if HUNT_PAYOUT_MIN <= pay <= HUNT_PAYOUT_MAX:
        s += 40.0 + min(pay, 20000) / 2000.0
    elif pay < HUNT_PAYOUT_MIN:
        s += pay / max(HUNT_PAYOUT_MIN, 1.0) * 8.0
    else:
        s += max(0.0, 12.0 - (pay - HUNT_PAYOUT_MAX) / 50000.0)
    if 1 <= nweb <= 12:
        s += 25.0
    elif 13 <= nweb <= 40:
        s += 10.0
    else:
        s -= 15.0
        c["popular"] = True
    if c.get("offers_bounties"):
        s += 8.0
    if c.get("denied"):
        s -= 80.0
        c["popular"] = True
    if pay > 200000:
        s -= 40.0
        c["popular"] = True
    # prefer smaller / less famous handles
    handle = c.get("handle") or ""
    if len(handle) >= 8:
        s += 4.0
    return round(s, 4)


def write_json(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2), encoding="utf-8")


def append_catalog(path: Path, rows: List[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing: Dict[str, str] = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line or line.startswith("slug"):
                continue
            existing[line.split("\t")[0]] = line
    for c in rows:
        existing[c["slug"]] = "\t".join(
            [
                c["slug"],
                f"{c.get('hunt_score', 0):.4f}",
                str(int(c.get("payout") or 0)),
                str(c.get("n_web") or 0),
                c.get("platform") or "",
                c.get("handle") or "",
                "1" if c.get("popular") else "0",
                (c.get("primary_url") or "")[:120],
            ]
        )
    header = "slug\thunt_score\tpayout\tn_web\tplatform\thandle\tpopular\tprimary"
    path.write_text(header + "\n" + "\n".join(existing.values()) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Discover public bounty WEB targets")
    ap.add_argument("--root", default=os.environ.get("HUNT_ROOT", "/root/monad/bounty-targets-hunt"))
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--max", type=int, default=MAX_CANDIDATES)
    args = ap.parse_args()

    root = Path(args.root)
    shared = root / "shared"
    pending = shared / "queue" / "pending"
    archive = shared / "queue" / "archive"
    state = shared / "state"
    vendor = root / "vendor" / "bounty-targets-data"
    pending.mkdir(parents=True, exist_ok=True)
    archive.mkdir(parents=True, exist_ok=True)
    state.mkdir(parents=True, exist_ok=True)

    deny_keys, deny_needles = load_deny(shared / "DENY_LIST.txt")
    print(f"[discover] sync feed {FEED_REPO}")
    git_sync(vendor)
    data_dir = vendor / "data"
    programs = iter_programs(data_dir)
    print(f"[discover] programs={len(programs)}")

    candidates: List[dict] = []
    for prog in programs:
        platform = prog.get("_platform") or "unknown"
        handle = norm(str(prog.get("handle") or prog.get("company_handle") or prog.get("name") or "unknown"))
        name = str(prog.get("name") or handle)
        url = str(prog.get("url") or "")
        status = norm(str(prog.get("submission_state") or prog.get("status") or "open"))
        if status and status not in ("open", "public", "online", ""):
            continue
        assets = in_scope_assets(prog)
        web: List[dict] = []
        for a in assets:
            ident = asset_id(a)
            if not ident or not eligible(a):
                continue
            at = asset_type(a)
            if not looks_web(at, ident):
                continue
            web.append(
                {
                    "id": ident,
                    "type": at,
                    "url": primary_url(ident),
                    "host": host_of(ident),
                    "instruction": (a.get("instruction") or a.get("description") or "")[:400],
                    "max_severity": a.get("max_severity") or a.get("impact") or "",
                }
            )
        if not web:
            continue
        concrete = [
            w
            for w in web
            if str(w.get("url") or "").startswith("http")
            and "*" not in str(w.get("url") or "")
            and looks_like_host_or_url(str(w.get("id") or w.get("url") or ""))
        ]
        primary = concrete[0] if concrete else None
        if primary is None:
            continue
        hosts = sorted({w["host"] for w in web if w.get("host")})
        slug = slugify(platform, handle)
        pay = payout_value(prog)
        offers = bool(prog.get("offers_bounties") or prog.get("offers_awards") or pay > 0)
        denied = is_denied(platform, handle, name, deny_keys, deny_needles)
        c = {
            "slug": slug,
            "platform": platform,
            "handle": handle,
            "name": name,
            "program_url": url,
            "website": str(prog.get("website") or ""),
            "payout": pay,
            "min_payout": min_payout_value(prog),
            "offers_bounties": offers,
            "n_web": len(web),
            "n_hosts": len(hosts),
            "primary_url": primary["url"],
            "primary_host": primary["host"],
            "assets": web[:40],
            "hosts": hosts[:40],
            "denied": denied,
            "popular": False,
            "first_seen": time.time(),
            "sources": [f"feed:{platform}"],
        }
        c["hunt_score"] = hunt_score(c)
        candidates.append(c)

    candidates.sort(key=lambda x: float(x.get("hunt_score") or 0), reverse=True)

    archived = 0
    for c in candidates:
        if archived >= MAX_ARCHIVE_WRITE:
            break
        write_json(archive / f"{c['slug']}.json", c)
        archived += 1
    append_catalog(state / "catalog.tsv", candidates[:MAX_ARCHIVE_WRITE])

    huntable: List[dict] = []
    for c in candidates:
        if c.get("popular") or c.get("denied"):
            continue
        if float(c.get("hunt_score") or 0) < MIN_SCORE:
            continue
        if float(c.get("payout") or 0) > HUNT_PAYOUT_MAX * 4:
            continue
        if not c.get("offers_bounties") and float(c.get("payout") or 0) <= 0:
            continue
        primary = str(c.get("primary_url") or "")
        if not primary.startswith("http") or "*" in primary:
            continue
        host = str(c.get("primary_host") or "").lower()
        if host in ("github.com", "gitlab.com", "play.google.com", "apps.apple.com"):
            continue
        huntable.append(c)

    keep: Set[str] = set()
    written = 0
    for c in huntable:
        if written >= args.max:
            break
        write_json(pending / f"{c['slug']}.json", c)
        keep.add(c["slug"] + ".json")
        written += 1
        print(
            f"[pending] hunt={c['hunt_score']:.1f} pay={int(c['payout'])} "
            f"web={c['n_web']} {c['platform']}:{c['handle']} {c['primary_url']}"
        )
    for old in pending.glob("*.json"):
        if old.name not in keep:
            old.unlink(missing_ok=True)

    summary = {
        "ts": time.time(),
        "programs": len(programs),
        "candidates": len(candidates),
        "archived": archived,
        "pending_written": written,
        "top_hunt": huntable[:10],
    }
    write_json(state / "last_discover.json", summary)
    print(f"[discover] archived={archived} pending={written}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
