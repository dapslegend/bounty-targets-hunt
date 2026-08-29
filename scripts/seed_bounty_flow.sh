#!/usr/bin/env bash
# Seed one WEB2 bounty-targets-hunt flow.
# NEVER remounts /work. NEVER kills BSC / other campaigns. NEVER docker-build.
# Live: FORCE_LIVE=1 DRY_RUN=0 ./scripts/seed_bounty_flow.sh <slug>
set -euo pipefail

ROOT_CAMPAIGN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PENTAGI_ROOT="${PENTAGI_ROOT:-/opt/web3/pentagi}"
PENTAGI_URL="${PENTAGI_URL:-https://127.0.0.1:8443}"
PROVIDER="${PENTAGI_PROVIDER:-grok}"
FORCE_LIVE="${FORCE_LIVE:-0}"
DRY_RUN="${DRY_RUN:-1}"
SLUG="${1:-}"

strip_env_quotes() {
  local v="${1-}"
  if [[ ${#v} -ge 2 ]]; then
    if [[ "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then v="${v:1:${#v}-2}"
    elif [[ "${v:0:1}" == "'" && "${v: -1}" == "'" ]]; then v="${v:1:${#v}-2}"; fi
  fi
  printf '%s' "$v"
}

if [[ -z "$SLUG" ]]; then
  echo "usage: $0 <slug>" >&2
  exit 2
fi

if [[ "$DRY_RUN" != "1" && -f "$PENTAGI_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PENTAGI_ROOT/.env"
  set +a
fi
PENTAGI_USER="$(strip_env_quotes "${PENTAGI_USER:-admin@pentagi.com}")"
PENTAGI_PASS="$(strip_env_quotes "${PENTAGI_PASS:-admin}")"

need() { [[ -s "$1" ]] || { echo "FATAL missing $1"; exit 1; }; }
need "$ROOT_CAMPAIGN/flows/01-bounty-web-program.md"
need "$ROOT_CAMPAIGN/shared/STEER.md"
need "$ROOT_CAMPAIGN/shared/WANT.md"
need "$ROOT_CAMPAIGN/shared/OOS.md"
need "$ROOT_CAMPAIGN/shared/REJECTED-FAMILIES.md"
need "$ROOT_CAMPAIGN/shared/AUTHORIZATION.md"

if [[ ! -f "$ROOT_CAMPAIGN/target/batch/$SLUG/PIN.txt" ]]; then
  python3 "$ROOT_CAMPAIGN/scripts/materialize_target.py" --root "$ROOT_CAMPAIGN" --slug "$SLUG"
fi
PIN="$ROOT_CAMPAIGN/target/batch/$SLUG/PIN.txt"
SCOPE="$ROOT_CAMPAIGN/target/batch/$SLUG/SCOPE.md"
AUTH="$ROOT_CAMPAIGN/target/batch/$SLUG/AUTHORIZATION.md"
need "$PIN"
need "$SCOPE"

FORBIDDEN_CLASSIFY_RE='WEB3|FORGE|SOLIDITY|FOUNDRY|KILN|METAMASK|STAKING|VALIDATOR|WITHDRAWER|ETHEREUM|EVM|DEFI|CREATE2|0X|MONAD|SOLANA|APTOS|IMMUNEFI|BLOCKCHAIN'

prompt_classify_ok() {
  local p="$1"
  local hits
  hits="$(python3 - "$p" "$FORBIDDEN_CLASSIFY_RE" <<'PY'
import re, sys
path, pat = sys.argv[1], sys.argv[2]
blob = open(path, encoding="utf-8").read().upper()
rx = re.compile(pat)
found = sorted(set(rx.findall(blob)))
print(",".join(found))
PY
)"
  if [[ -n "${hits}" ]]; then
    echo "FATAL: assembled prompt would classify as wrong family (tokens: ${hits})"
    return 1
  fi
  if ! grep -qi 'WEB2' "$p"; then
    echo "FATAL: assembled prompt missing WEB2 marker"
    return 1
  fi
  return 0
}

COOKIE="$(mktemp)"
PROMPT="$(mktemp)"
GQL="$(mktemp)"
trap 'rm -f "$COOKIE" "$PROMPT" "$GQL" 2>/dev/null' EXIT

{
  echo "# [WEB2-GROK] AUTHORIZED public bug-bounty WEB hunt — bounty-targets-hunt ${SLUG}"
  echo "stack: web2. runner=python3. default_command=python3 poc.py."
  echo "AUTHORIZED: public program listed in the arkadiyt bounty-targets dump. Stay in-scope."
  echo "Never DoS. Never credential-stuff real customer accounts. Never store passwords. Never exfiltrate PII."
  echo ""
  echo "ASSIGNED PROGRAM slug=${SLUG}"
  echo "Artifacts: /work/bounty/target/batch/${SLUG}/  (PIN.txt SCOPE.md AUTHORIZATION.md program.json in_scope.tsv)"
  echo "Board: /work/bounty/shared/STEER.md WANT.md OOS.md REJECTED-FAMILIES.md AUTHORIZATION.md"
  echo "Flow: /work/bounty/flows/01-bounty-web-program.md"
  echo "PoC: /work/bounty/poc/poc.py then web2_poc_runner."
  echo "Do not hunt /work/target (different campaign). Do not remount. Do not kill other campaigns."
  echo ""
  echo "Critical bar: RCE (uid= / whoami) OR SQLi that reached a real DBMS. XSS / open redirect / clickjacking = LOW never Crit."
  echo "CONFIRM only after web2_poc_runner PASS with raw terminal output. Grok cannot CONFIRM."
  echo "swarm_chat action=broadcast topic target_claim before deep work. Poll before pivoting."
  echo "Recon budget 3 steps/host then playwright_runner op=dump. Persist cookies/headers and replay."
  echo "sqlmap_runner technique=BEUSTQ + cookies. After injection: list_dbs=true / list_tables=true."
  echo "finding_id W2H-xxx. owner_flow=bounty-web-program"
  echo "15 min dead primary → next in-scope URL on THIS program only."
  echo ""
  echo "## STEER"
  cat "$ROOT_CAMPAIGN/shared/STEER.md"
  echo ""
  echo "## WANT"
  cat "$ROOT_CAMPAIGN/shared/WANT.md"
  echo ""
  echo "## OOS"
  cat "$ROOT_CAMPAIGN/shared/OOS.md"
  echo ""
  echo "## REJECTED FAMILIES"
  cat "$ROOT_CAMPAIGN/shared/REJECTED-FAMILIES.md"
  echo ""
  echo "## AUTHORIZATION"
  cat "$ROOT_CAMPAIGN/shared/AUTHORIZATION.md"
  echo ""
  echo "## FLOW"
  cat "$ROOT_CAMPAIGN/flows/01-bounty-web-program.md"
  echo ""
  echo "## LIVE PIN"
  cat "$PIN"
  echo ""
  echo "## SCOPE (this program)"
  cat "$SCOPE"
  echo ""
  echo "## PROGRAM AUTHORIZATION"
  cat "$AUTH" 2>/dev/null || true
  echo ""
  echo "BEGIN immediately. Read SCOPE + STEER. Claim primary host. Dump with playwright_runner. Hunt RCE or SQLi-to-DB."
  echo "stack: web2"
} > "$PROMPT"

if ! prompt_classify_ok "$PROMPT"; then
  echo "FATAL classify" >&2
  exit 1
fi

BYTES="$(wc -c < "$PROMPT" | tr -d ' ')"
echo "[seed] slug=$SLUG prompt_bytes=$BYTES DRY_RUN=$DRY_RUN FORCE_LIVE=$FORCE_LIVE"

if [[ "$DRY_RUN" == "1" || "$FORCE_LIVE" != "1" ]]; then
  echo "[DRY_RUN] would createFlow provider=$PROVIDER title=[WEB2-GROK] bounty-targets-hunt $SLUG"
  exit 0
fi

payload="$(PENTAGI_USER="$PENTAGI_USER" PENTAGI_PASS="$PENTAGI_PASS" python3 -c 'import json,os; print(json.dumps({"mail":os.environ["PENTAGI_USER"].strip().strip("\"'\''"),"password":os.environ["PENTAGI_PASS"].strip().strip("\"'\''")}))')"
code="$(curl -sk -c "$COOKIE" -b "$COOKIE" -H 'Content-Type: application/json' \
  -X POST "${PENTAGI_URL}/api/v1/auth/login" -d "$payload" -o /tmp/bounty_hunt_login.json -w '%{http_code}')"
if [[ "$code" != "200" ]]; then
  echo "FATAL login http $code"
  exit 1
fi

python3 - "$PROVIDER" "$PROMPT" "$GQL" <<'PY'
import json, sys
p, prompt, out = sys.argv[1], sys.argv[2], sys.argv[3]
inp = open(prompt, encoding="utf-8").read()
json.dump({
  "query": "mutation($p:String!,$i:String!){createFlow(modelProvider:$p,input:$i){id title status}}",
  "variables": {"p": p, "i": inp},
}, open(out, "w"))
PY

RESP="/tmp/bounty_hunt_flow_${SLUG}.json"
curl -sk --max-time 180 -b "$COOKIE" -c "$COOKIE" -H 'Content-Type: application/json' \
  -X POST "${PENTAGI_URL}/api/v1/graphql" -d @"$GQL" -o "$RESP" || true

FID="$(python3 -c 'import json,sys
try:
 d=json.load(open(sys.argv[1])); print(d.get("data",{}).get("createFlow",{}).get("id") or "")
except Exception:
 print("")
' "$RESP")"
if [[ -z "$FID" ]]; then
  FID="$(docker exec pgvector psql -U postgres -d pentagidb -Atc \
    "SELECT id FROM flows WHERE created_at > now() - interval '3 minutes' AND title ILIKE '%bounty-targets-hunt%' ORDER BY id DESC LIMIT 1;" 2>/dev/null || true)"
fi
if [[ -z "$FID" ]]; then
  echo "FATAL no flow id"
  python3 -c 'import pathlib; p=pathlib.Path("/tmp/bounty_hunt_flow_'"$SLUG"'.json"); print(p.read_text()[:800] if p.exists() else "no resp")' || true
  exit 1
fi

docker exec pgvector psql -U postgres -d pentagidb -c \
  "UPDATE flows SET title=('[WEB2-GROK] bounty-targets-hunt ${SLUG} f${FID}' || COALESCE(substring(title from ' models:.*'), '')) WHERE id=${FID};" \
  >/dev/null || true

mkdir -p "$ROOT_CAMPAIGN/shared/state" "$ROOT_CAMPAIGN/shared/queue/active"
echo "$FID" >> "$ROOT_CAMPAIGN/shared/state/flow_ids.txt"
echo "$FID" > "$ROOT_CAMPAIGN/shared/state/last_flow_id.txt"
if [[ -f "$ROOT_CAMPAIGN/shared/queue/pending/${SLUG}.json" ]]; then
  mv -f "$ROOT_CAMPAIGN/shared/queue/pending/${SLUG}.json" \
    "$ROOT_CAMPAIGN/shared/queue/active/${SLUG}.f${FID}.json" || true
fi
echo "[seed] created flow_id=$FID slug=$SLUG"
echo "$FID"
