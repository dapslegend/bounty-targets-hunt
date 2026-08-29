# 01 — public bounty program (WEB2)

## Primary (YOURS — claim first)
Assigned program + primary URL are in `/work/bounty/target/batch/<slug>/PIN.txt` and `SCOPE.md`.
Do not invent hosts. Do not hunt `/work/target` (different campaign).

## Hunt
1. `swarm_chat` broadcast `target_claim` `{"program":"<handle>","host":"<primary>","phase":"sql"}`
2. Read SCOPE.md + AUTHORIZATION.md + program policy URL. Stay in-scope.
3. `playwright_runner` op=dump the primary URL → `/work/source/<host>/`
4. Replay cookies. Hunt login / search / id / upload / api on **this host**.
5. Goal: **RCE or SQLi-to-DB**. XSS is LOW.
6. 15 min dead → next in-scope URL on THIS program (PIN backups). Never a peer program.

## Reject
A-XSS-AS-CRIT. A-TYPE-ONLY-SQLI. A-OOS-HOST. A-POLICY-SKIP. A-WRONG-STACK. A-DOS. A-MEGA-VRP.

finding_id W2H-xxx. owner_flow=bounty-web-program
stack: web2
