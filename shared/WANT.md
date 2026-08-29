# WANT — WEB2 bounty-scope

Critical:
1. **RCE** — POSIX `uid=` / `gid=` / `euid=` or Windows `NT AUTHORITY`. Bare `whoami` in notes is not proof.
2. **SQLi-to-DB** — injector reached a real DBMS (`available databases [N>0]` / dumped table / listed tables). `"No available databases"` is FAIL. Type-only is High.
3. **Other-tenant / ATO leak** — private key, AWS secret, or another user's session/PII via IDOR.

High (in-scope hunt goals — file these):
- Unauth **secret/key/token** leak (AWS keys, private keys, DB URLs with passwords, bearer tokens of others)
- **SSRF** that returns cloud metadata (`169.254.169.254` / `metadata.google.internal`) or an internal secret body
- **LFI** that reads secrets (`wp-config`, `.env`, `/etc/shadow`, private keys) — `/etc/passwd` alone is Low
- **IDOR / auth bypass** that yields ATO or PII (Crit if other-user PII/session)
- Type-only SQLi (boolean/time without `--dbs`)

LOW only (never Crit, never High):
- XSS, open redirect, clickjacking, missing headers
- User-enum (signup vs login), verbose errors without DB reach
- Nuclei info, CSP/HSTS, clickjacking headers

PoC: python `poc.py` under `/work/bounty/poc` then `web2_poc_runner`. Raw curl/sqlmap stdout required.
finding_id **W2H-xxx**.
