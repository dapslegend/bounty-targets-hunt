#!/usr/bin/env bash
# 24/7 WEB2: pull arkadiyt bounty-targets-data → archive → seed N flows/hour.
# NEVER remounts /work. NEVER kills BSC. NEVER starts a second BSC loop.
#
#   DRY_RUN=1 ./scripts/forever_loop.sh --once
#   FORCE_LIVE=1 DRY_RUN=0 INTERVAL_SEC=3600 BATCH_SIZE=2 ./scripts/forever_loop.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HUNT_ROOT="$ROOT"
SCRIPTS="$ROOT/scripts"
SHARED="$ROOT/shared"
STATE="$SHARED/state"
PENDING="$SHARED/queue/pending"
ACTIVE="$SHARED/queue/active"
DONE="$SHARED/queue/done"
REJECTED="$SHARED/queue/rejected"
ARCHIVE="$SHARED/queue/archive"
LOG_DIR="$STATE/logs"
mkdir -p "$PENDING" "$ACTIVE" "$DONE" "$REJECTED" "$ARCHIVE" "$LOG_DIR" "$STATE" "$ROOT/target/batch"

INTERVAL_SEC="${INTERVAL_SEC:-3600}"
DISCOVER_EVERY_SEC="${DISCOVER_EVERY_SEC:-300}"
BATCH_SIZE="${BATCH_SIZE:-2}"
MAX_ACTIVE_FLOWS="${MAX_ACTIVE_FLOWS:-3}"
MIN_SCORE="${MIN_SCORE:-20}"
MAX_PENDING="${MAX_PENDING:-400}"
MAX_ARCHIVE="${MAX_ARCHIVE:-8000}"
DRY_RUN="${DRY_RUN:-1}"
FORCE_LIVE="${FORCE_LIVE:-0}"
ONCE=0
for arg in "$@"; do
  case "$arg" in
    --once) ONCE=1 ;;
  esac
done

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*"; echo "[$(ts)] $*" >> "$LOG_DIR/forever.log"; }

count_bounty_active() {
  docker exec pgvector psql -U postgres -d pentagidb -Atc \
    "SELECT count(*) FROM flows WHERE status IN ('running','waiting','created') AND title ILIKE '%bounty-targets-hunt%';" \
    2>/dev/null || echo 0
}

count_web2_grok() {
  docker exec pgvector psql -U postgres -d pentagidb -Atc \
    "SELECT count(*) FROM flows WHERE status IN ('running','waiting','created') AND title ILIKE '%[WEB2-GROK]%';" \
    2>/dev/null || echo 0
}

count_all_running() {
  docker exec pgvector psql -U postgres -d pentagidb -Atc \
    "SELECT count(*) FROM flows WHERE status IN ('running','waiting','created');" \
    2>/dev/null || echo 0
}

pick_pending_batch() {
  local n="$1"
  python3 - "$n" <<'PY'
import json, os, sys
from pathlib import Path
n = int(sys.argv[1])
pending = Path(os.environ["HUNT_ROOT"]) / "shared/queue/pending"
min_score = float(os.environ.get("MIN_SCORE", "20"))
cands = []
for p in pending.glob("*.json"):
    try:
        d = json.loads(p.read_text())
    except Exception:
        continue
    hs = float(d.get("hunt_score") or 0)
    if hs < min_score:
        continue
    if d.get("popular") is True or d.get("denied") is True:
        continue
    cands.append((hs, str(p)))
cands.sort(reverse=True)
for _, p in cands[:n]:
    print(p)
PY
}

mark_queue() {
  local src="$1" dest_dir="$2"
  mkdir -p "$dest_dir"
  [[ -f "$src" ]] || return 0
  mv -f "$src" "$dest_dir/" 2>/dev/null || { cp -f "$src" "$dest_dir/" && rm -f "$src"; } || true
}

discover_pass() {
  log "discover pass start"
  python3 "$SCRIPTS/discover_bounty_targets.py" --root "$ROOT" --once \
    >> "$LOG_DIR/discover.log" 2>&1 || log "WARN discover exit $?"
  local n
  n="$(find "$PENDING" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  log "pending candidates=$n"
}

seed_batch() {
  local slots="$1"
  [[ "$slots" -gt 0 ]] || { log "no slots"; return 0; }
  local files
  files="$(MIN_SCORE="$MIN_SCORE" HUNT_ROOT="$ROOT" pick_pending_batch "$slots" || true)"
  if [[ -z "${files}" ]]; then
    log "no pending candidate above MIN_SCORE=$MIN_SCORE"
    return 1
  fi
  local cand slug
  while IFS= read -r cand; do
    [[ -n "$cand" && -f "$cand" ]] || continue
    slug="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("slug",""))' "$cand")"
    [[ -n "$slug" ]] || continue
    log "materialize $slug"
    if ! python3 "$SCRIPTS/materialize_target.py" --root "$ROOT" --slug "$slug" >> "$LOG_DIR/materialize.log" 2>&1; then
      log "WARN materialize failed $slug → rejected"
      mark_queue "$cand" "$REJECTED"
      continue
    fi
    if [[ "$DRY_RUN" == "1" || "$FORCE_LIVE" != "1" ]]; then
      log "DRY_RUN — materialized $slug (no createFlow)"
      continue
    fi
    log "FORCE_LIVE seed $slug"
    if FORCE_LIVE=1 DRY_RUN=0 bash "$SCRIPTS/seed_bounty_flow.sh" "$slug" >> "$LOG_DIR/seed.log" 2>&1; then
      # seeder already moves pending → active; do not require the file
      mark_queue "$cand" "$ACTIVE"
      echo "$(ts) $slug" >> "$STATE/seeded.txt"
      log "seeded OK $slug"
    else
      log "WARN seed failed $slug — keep pending"
    fi
    sleep 2
  done <<< "$files"
}

prune_pending() {
  python3 - <<'PY'
import json, os
from pathlib import Path
root = Path(os.environ["HUNT_ROOT"])
pending = root / "shared/queue/pending"
archive = root / "shared/queue/archive"
max_pending = int(os.environ.get("MAX_PENDING", "400"))
max_archive = int(os.environ.get("MAX_ARCHIVE", "8000"))
archive.mkdir(parents=True, exist_ok=True)

def rank(d):
    return float(d.get("hunt_score") or 0)

cands = []
for f in pending.glob("*.json"):
    try:
        d = json.loads(f.read_text())
        cands.append((rank(d), f))
    except Exception:
        f.unlink(missing_ok=True)
cands.sort(reverse=True)
for _, f in cands[max_pending:]:
    dest = archive / f.name
    if not dest.exists():
        f.replace(dest)
    else:
        f.unlink(missing_ok=True)

acands = []
for f in archive.glob("*.json"):
    try:
        d = json.loads(f.read_text())
        acands.append((float(d.get("hunt_score") or 0), f))
    except Exception:
        f.unlink(missing_ok=True)
acands.sort(reverse=True)
for _, f in acands[max_archive:]:
    f.unlink(missing_ok=True)
PY
}

cycle() {
  log "==== cycle start DRY_RUN=$DRY_RUN FORCE_LIVE=$FORCE_LIVE BATCH_SIZE=$BATCH_SIZE INTERVAL=${INTERVAL_SEC}s ===="
  local avail_k
  avail_k="$(df -Pk /root | awk 'NR==2{print $4}')"
  if [[ "${avail_k:-0}" -lt 400000 ]]; then
    log "WARN low disk ${avail_k}K — discover only"
    discover_pass || true
    return 0
  fi

  discover_pass || true

  local bounty_active web2_active all_active slots grok_cap remain
  bounty_active="$(count_bounty_active | tr -d '[:space:]')"
  web2_active="$(count_web2_grok | tr -d '[:space:]')"
  all_active="$(count_all_running | tr -d '[:space:]')"
  bounty_active="${bounty_active:-0}"
  web2_active="${web2_active:-0}"
  all_active="${all_active:-0}"
  grok_cap="${HUSTLER_WEB2_GROK_MAX_CONCURRENT:-3}"
  total_cap="${HUSTLER_MAX_ACTIVE_FLOWS:-12}"
  slots="$BATCH_SIZE"
  if [[ "$bounty_active" -ge "$MAX_ACTIVE_FLOWS" ]]; then
    slots=0
  else
    remain=$((MAX_ACTIVE_FLOWS - bounty_active))
    [[ "$remain" -lt "$slots" ]] && slots="$remain"
  fi
  if [[ "$web2_active" -ge "$grok_cap" ]]; then
    slots=0
  else
    remain=$((grok_cap - web2_active))
    [[ "$remain" -lt "$slots" ]] && slots="$remain"
  fi
  if [[ "$all_active" -ge "$total_cap" ]]; then
    slots=0
  else
    remain=$((total_cap - all_active))
    [[ "$remain" -lt "$slots" ]] && slots="$remain"
  fi
  log "flows bounty=$bounty_active web2=$web2_active all=$all_active seed_slots=$slots max=$MAX_ACTIVE_FLOWS grok_cap=$grok_cap total_cap=$total_cap"

  seed_batch "$slots" || true
  prune_pending || true
  log "==== cycle end ===="
}

discover_window() {
  local window="$1"
  local every="${DISCOVER_EVERY_SEC}"
  [[ "$every" -lt 60 ]] && every=60
  local start now elapsed
  start="$(date +%s)"
  log "discover window ${window}s every ${every}s (save continuously)"
  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))
    [[ "$elapsed" -ge "$window" ]] && break
    discover_pass || true
    prune_pending || true
    now="$(date +%s)"
    elapsed=$((now - start))
    local remain=$((window - elapsed))
    [[ "$remain" -le 0 ]] && break
    local nap="$every"
    [[ "$nap" -gt "$remain" ]] && nap="$remain"
    log "discover nap ${nap}s remain=${remain}s"
    sleep "$nap"
  done
}

log "forever_loop start root=$ROOT interval=${INTERVAL_SEC}s discover_every=${DISCOVER_EVERY_SEC}s batch=$BATCH_SIZE once=$ONCE"
if [[ "$ONCE" == "1" ]]; then
  cycle
  exit 0
fi

while true; do
  cycle || log "cycle error $?"
  discover_window "$INTERVAL_SEC" || log "discover_window error $?"
done
