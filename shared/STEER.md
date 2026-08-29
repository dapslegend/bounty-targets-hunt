# STEER — WEB2 public bounty-scope hunt

1. This is **WEB2**. Never call slither / echidna / medusa / trident / cargo-fuzz. Wrong stack.
2. Critical bar: **RCE** (`uid=` / `whoami`) **OR SQLi that reached a real DBMS**. Type-only boolean/time is High, not Crit. XSS / open redirect / clickjacking = LOW never Crit.
3. CONFIRM only after `web2_poc_runner` PASS with raw terminal output. Grok cannot CONFIRM.
4. One primary program + one primary host per flow. `swarm_chat` action=broadcast topic `target_claim` before deep work. Poll before pivoting.
5. Recon budget **3 steps/host** then STOP: fingerprint + WAF + live. Then `playwright_runner` op=`dump` → `/work/source`.
6. Persist cookies/headers to `/work/cookies.txt` `/work/headers.txt` `/work/playwright_state.json` and replay.
7. `sqlmap_runner` technique=BEUSTQ + cookies. After any injection class: `list_dbs=true` / `list_tables=true`.
8. Stay **in-scope**. Read `/work/bounty/target/batch/<slug>/SCOPE.md` and the program policy URL before any probe. Out-of-scope hosts are forbidden.
9. Prefer unauthenticated / low-priv web user. No credential stuffing of real customer accounts. No DoS. No brute-force lockouts.
10. finding_id **W2H-xxx**. Never store customer passwords. Never exfiltrate PII off-box.
11. 15 min dead primary → pivot to the next in-scope URL on THIS program, not a peer program.
12. Artifacts live under `/work/bounty/` (this pack). `/work/target` is a **different campaign** — do not hunt it.
13. Do not remount / kill other campaigns from inside the agent. Campaign mounts are operator-owned.
14. Never run `python3 /work/poc/poc.py` or any leftover harness from another campaign. PoC is `/work/bounty/poc/*.py` only. Dump with `playwright_runner` — do not guess SPA params via urllib.
