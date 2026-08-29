# OOS — WEB2 bounty-scope

- Hosts / assets **not** listed in this flow's SCOPE.md in-scope list
- Explicit out-of-scope from the program policy
- Wildcard exclusions (e.g. `*.example.com` in-scope but `excluded.example.com` OOS)
- Mobile apps / IoT / hardware / source-zip unless the assigned asset is that type (this hunt is web URL/API)
- Credential stuffing / password spraying real customer accounts
- DoS, flood, lockout campaigns
- Phishing / social engineering
- Changing production data beyond injection proof
- Storing or exfiltrating real PII off-box
- Wrong-stack contract fuzzers / chain tools
- XSS / open redirect as Critical
- Other campaigns mounted at `/work/target` (not this pack)
