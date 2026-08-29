# REJECTED FAMILIES — WEB2 bounty-scope

| id | family | why |
|---|---|---|
| A-XSS-AS-CRIT | XSS / open redirect / clickjacking claimed Critical | LOW only |
| A-TYPE-ONLY-SQLI | sqlmap Type: boolean/time without list_dbs / dumped table | High, not Crit |
| A-HTTP-000 | probe http_code 000 treated as "not vulnerable" | network fail, retry |
| A-OOS-HOST | host not on this program in-scope list | OOS |
| A-POLICY-SKIP | did not read program policy before testing | stop |
| A-FOREIGN-CAMPAIGN | leftover hyps from a different campaign | different campaign |
| A-SELF-LOGIN | "I can log in with my own test account" | not a finding |
| A-MISSING-HEADER | CSP / HSTS / X-Frame-Options | LOW |
| A-NUCLEI-INFO | nuclei info without body proof | reject |
| A-SIMULATED | placeholder / if True / example.com | reject |
| A-WRONG-STACK | slither/echidna/medusa/trident on this campaign | wrong stack |
| A-DOS | flood / lockout / stress | forbidden |
| A-MEGA-VRP | Google / Meta / Apple / Microsoft VRP as primary | skip — too noisy |
