# WANT — WEB2 bounty-scope

Critical only:
1. **RCE** — command exec proof (`uid=` / `gid=` / `whoami` / interactive shell).
2. **SQLi-to-DB** — injector reached a real DBMS. Blind `--dbs`/`--tables` **and** UNION/stacked dump both count. Type-only is High.

High (in-scope, not the hunt goal):
- IDOR / auth bypass that yields ATO or PII
- SSRF that hits metadata / internal
- LFI / path traversal that reads secrets
- Account takeover without cred stuffing

LOW only (never Crit):
- XSS, open redirect, clickjacking, missing headers, verbose errors without DB reach

PoC: python `poc.py` under `/work/bounty/poc` then `web2_poc_runner`. Raw curl/sqlmap stdout required.
finding_id **W2H-xxx**.
