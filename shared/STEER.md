# STEER — WEB2 public bounty-scope hunt

1. This is **WEB2**. Never call slither / echidna / medusa / trident / cargo-fuzz. Wrong stack.
2. Critical bar: **RCE** (`uid=` / `gid=` / `euid=` / `NT AUTHORITY`) **OR SQLi that reached a real DBMS** **OR other-tenant/private-key leak**. Type-only boolean/time is High, not Crit. XSS / open redirect / clickjacking / user-enum = LOW never Crit.
3. High hunt (file these): unauth secret/key leak, SSRF-to-metadata with body, LFI of secrets, IDOR+PII. Confirm as HIGH unless other-tenant/ATO.
4. CONFIRM only after `web2_poc_runner` PASS with raw terminal output. Grok cannot CONFIRM.
5. One primary program + one primary host per flow. `swarm_chat` action=broadcast topic `target_claim` before deep work. Poll before pivoting.
6. Recon budget **3 steps/host** then STOP: fingerprint + WAF + live. Then `playwright_runner` op=`dump` → `/work/source`.
7. Persist cookies/headers to `/work/cookies.txt` `/work/headers.txt` `/work/playwright_state.json` and replay.
8. `sqlmap_runner` technique=BEUSTQ + cookies. After any injection class: `list_dbs=true` / `list_tables=true`. `"No available databases"` is not DB reach.
9. Stay **in-scope**. Read `/work/bounty/target/batch/<slug>/SCOPE.md` and the program policy URL before any probe. Out-of-scope hosts are forbidden.
10. Prefer unauthenticated / low-priv web user. No credential stuffing of real customer accounts. No DoS. No brute-force lockouts.
11. finding_id **W2H-xxx**. Never store customer passwords. Never exfiltrate PII off-box.
12. 15 min dead primary → pivot to the next in-scope URL on THIS program, not a peer program.
13. Artifacts live under `/work/bounty/` (this pack). `/work/target` is a **different campaign** — do not hunt it.
14. Do not remount / kill other campaigns from inside the agent. Campaign mounts are operator-owned.
15. Never run `python3 /work/poc/poc.py` or any leftover harness from another campaign. PoC is `/work/bounty/poc/*.py` only. Dump with `playwright_runner` — do not guess SPA params via urllib.
