# bounty-targets-hunt

24/7 PentAGI **WEB2** feeder from [arkadiyt/bounty-targets-data](https://github.com/arkadiyt/bounty-targets-data) (Hackerone / Bugcrowd / Intigriti / YesWeHack / Federacy scopes).

Runs **alongside** the BSC web3 hunt. Does **not** steal `/work` — pack is extra-mounted at `/work/bounty`.

PentAGI core stays generic. This pack lives under `/root/monad/bounty-targets-hunt`.

## Clone next time

```bash
git clone https://github.com/dapslegend/bounty-targets-hunt.git /root/monad/bounty-targets-hunt
# feed is pulled at runtime into vendor/ (gitignored)
```

Requires existing PentAGI at `/opt/web3/pentagi` with GraphQL on `:8443`.

## Alongside web3

`/work/target` `/work/shared` `/work/poc` stay on **bsc-mainnet-hunt**.
This pack is visible to agents as:

- `/work/bounty/target`
- `/work/bounty/shared`
- `/work/bounty/poc`

Attach extra mounts (recreates pentagi, no-build; does not remount `/work`):

```bash
DRY_RUN=0 /root/monad/bounty-targets-hunt/scripts/attach_bounty_mount.sh
```

## Loop

```bash
FORCE_LIVE=1 DRY_RUN=0 INTERVAL_SEC=3600 DISCOVER_EVERY_SEC=300 BATCH_SIZE=3 MAX_ACTIVE_FLOWS=4 \
  nohup /root/monad/bounty-targets-hunt/scripts/forever_loop.sh \
  >> /root/monad/bounty-targets-hunt/shared/state/logs/nohup.log 2>&1 &
```

During `INTERVAL_SEC` the loop keeps pulling the feed and **archives** in-scope web assets. Only mid-payout, unpopular, URL-like targets go to `pending/` for seeding.

## Knobs

| env | default | meaning |
|-----|---------|---------|
| INTERVAL_SEC | 3600 | seed cycle period |
| DISCOVER_EVERY_SEC | 300 | feed refresh inside the hour |
| BATCH_SIZE | 3 | programs seeded per hour |
| MAX_ACTIVE_FLOWS | 4 | cap concurrent bounty-targets-hunt flows |
| MIN_SCORE | 20 | min hunt_score to seed |
| HUNT_PAYOUT_MIN / HUNT_PAYOUT_MAX | 500 / 50000 | skip VRP whales and $0 |
| FORCE_LIVE / DRY_RUN | 0 / 1 | createFlow only when FORCE_LIVE=1 DRY_RUN=0 |

## Rules

Authorized public bug-bounty scope only. Stay on listed in-scope web assets. Read the program policy before testing. Never DoS. Never out-of-scope. Never store secrets. Crit = RCE or SQLi-to-DB.

finding_id **W2H-xxx**. Titles `[WEB2-GROK]`. stack=web2 runner=python3.
