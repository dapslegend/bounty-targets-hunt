#!/usr/bin/env bash
# Append bounty-targets-hunt as EXTRA mount at /work/bounty.
# NEVER changes /work/target /work/shared /work/poc (those stay BSC).
# Never docker-build. Never print secrets.
# Usage: DRY_RUN=0 ./scripts/attach_bounty_mount.sh
set -euo pipefail
CAMPAIGN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PENTAGI_ROOT="${PENTAGI_ROOT:-/opt/web3/pentagi}"
DRY_RUN="${DRY_RUN:-1}"
BOUNTY_BIND="${CAMPAIGN}:/work/bounty:rw"
BOUNTY_MIRROR="${CAMPAIGN}:${CAMPAIGN}:rw"

echo "[attach] campaign=$CAMPAIGN DRY_RUN=$DRY_RUN bind=$BOUNTY_BIND"

python3 - "$BOUNTY_BIND" "$BOUNTY_MIRROR" <<'PY'
from pathlib import Path
import sys
binds = [sys.argv[1], sys.argv[2]]
candidates = [Path("/opt/web3/pentagi/.env"), Path("/root/monad/pentagi/.env")]
seen = set()
for p in candidates:
    try:
        rp = p.resolve()
    except Exception:
        rp = p
    if rp in seen or not p.exists():
        continue
    seen.add(rp)
    lines = p.read_text().splitlines()
    out = []
    found = False
    for line in lines:
        if not line or line.lstrip().startswith("#") or "=" not in line:
            out.append(line)
            continue
        k, v = line.split("=", 1)
        if k != "PENTAGI_AUDIT_EXTRA_MOUNTS":
            out.append(line)
            continue
        found = True
        raw = v.strip().strip('"').strip("'")
        parts = [x.strip() for x in raw.split(",") if x.strip()]
        for bind in binds:
            if bind not in parts:
                parts.append(bind)
        val = ",".join(parts)
        if any(c in val for c in " \t") and not (val.startswith('"') or val.startswith("'")):
            val = f'"{val}"'
        out.append(f"{k}={val}")
        print(f"EXTRA_MOUNTS now has {len(parts)} binds")
    if not found:
        val = ",".join(binds)
        if any(c in val for c in " \t"):
            val = f'"{val}"'
        out.append(f"PENTAGI_AUDIT_EXTRA_MOUNTS={val}")
    p.write_text("\n".join(out) + "\n")
    print(f"Updated {p}")
if not seen:
    print("WARN: no .env found")
    sys.exit(1)
PY

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] skip compose recreate — /work stays BSC"
  exit 0
fi

cd "$PENTAGI_ROOT"
docker compose --env-file .env up -d --no-deps --force-recreate --no-build pentagi
echo "[attach] waiting for pentagi..."
sleep 10
echo "[attach] /work mounts (must still be bsc-mainnet-hunt):"
docker inspect pentagi --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep -E '/work|bsc|bounty' || true
echo "[attach] EXTRA_MOUNTS in container:"
docker exec pentagi sh -c 'printf %s "$PENTAGI_AUDIT_EXTRA_MOUNTS"' | tr ',' '\n' || true
echo
echo "[attach] done — /work unchanged; /work/bounty extra-mounted for new terminals"
