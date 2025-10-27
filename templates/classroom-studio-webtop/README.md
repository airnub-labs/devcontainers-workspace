# Classroom Studio (Webtop) Template

Multi-container template featuring a headless development container plus a `linuxserver/webtop` sidecar for touch-friendly Chrome debugging. Template options let you:

- Pick whether the webtop mounts managed Chrome policies (`policyMode`).
- Override the policy file that gets mounted via `chromePolicies` (leave blank to follow the selected policy mode).
- Adjust the forwarded desktop port (`webtopPort`).
