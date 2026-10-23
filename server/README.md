# Gravelight game server

Accounts, cloud saves, friends, clans, clan chat, the clan raid, parties and
referrals all run on [Nakama](https://heroiclabs.com/nakama/) 3.30 with our
own Lua modules in `nakama/modules/`. The game works fully offline without it:
every online feature hides itself when the server can't be reached.

## What lives where

| File | What it does |
|---|---|
| `nakama/modules/gravelight.lua` | RPCs (bootstrap, names, progress, saves, transfer codes, clans, reports, raid, referrals) and hooks that guard chat, groups and accounts |
| `nakama/modules/gl_rewards.lua` | Every reward number: welcome gift, referral milestones, recruiter tiers, raid tuning |
| `nakama/modules/gl_filter.lua` | Name and chat filter: rude words, links, contact details |
| `nakama/gravelight.yml` | Nakama settings (session lengths, party size) |
| `docker-compose.yml`, `Caddyfile` | Production stack: Postgres, Nakama, Caddy for HTTPS, nightly backups |
| `test/smoke.py`, `test/run_local.sh` | End-to-end test against a local Nakama |

## Deploy (about 20 minutes)

1. Rent a small Linux VPS (2 vCPU / 4 GB is plenty to start; roughly
   $20–40 a month, plus $10–20 if you add managed backups). Install Docker.
2. Point a domain's DNS A record (for example `play.yourgame.com`) at it and
   open ports 80 and 443.
3. Copy this folder to the server, then `cp .env.example .env` and fill every
   value. Generate keys with `openssl rand -hex 24`.
4. `docker compose up -d`. Caddy fetches the HTTPS certificate on first start.
5. In the game, set `HOST` and `SERVER_KEY` in `src/net/net_config.gd` to the
   domain and the `SERVER_KEY` you chose, and ship a build.

Updating server logic: edit the Lua modules, copy them up, and
`docker compose restart nakama`. The modules are read at start.

## Test server on your own computer

Free and quick to start, online only while the computer is on. Needs Docker.

1. In this folder: `cp .env.example .env` and fill the keys (`DOMAIN` is
   unused here). Then start everything but Caddy:
   ```
   docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d postgres nakama backup
   ```
2. Tunnel it to a fixed HTTPS address. A free [ngrok](https://ngrok.com)
   account includes one static domain, so the game's address never changes:
   `ngrok http 7350 --url=<name>.ngrok-free.app`.
3. Set `HOST` (the ngrok domain) and `SERVER_KEY` in `src/net/net_config.gd`.

## Free test server (Oracle Cloud Always Free)

Good for testing with friends at $0. Oracle's free ARM machine (2 CPUs and
12 GB as of 2026) runs the same stack as production.

1. Make an account at [cloud.oracle.com](https://cloud.oracle.com). It asks
   for a card to verify you; Always Free resources are never charged.
2. Compute › Instances › Create: image **Ubuntu 24.04**, shape
   **VM.Standard.A1.Flex** (2 OCPU, 12 GB). Add your SSH key. If it says
   "out of capacity", try another availability domain or try again later.
3. Open the instance's subnet › Security List › Add Ingress Rules: source
   `0.0.0.0/0`, TCP, destination ports `80,443`.
4. Get a free name at [duckdns.org](https://www.duckdns.org) (for example
   `gravelight-test.duckdns.org`) and set its IP to the instance's public IP.
5. Copy this folder up and run the setup script:
   ```
   scp -r server ubuntu@<ip>:~/
   ssh ubuntu@<ip> 'sh ~/server/setup_vm.sh gravelight-test.duckdns.org'
   ```
   It installs Docker, opens the VM's own firewall, writes `.env` with fresh
   keys, starts everything, and prints the `SERVER_KEY`.
6. In `src/net/net_config.gd` set `HOST` to the DuckDNS name and
   `SERVER_KEY` to the printed key, then ship a build.

## Testing locally

```
NAKAMA_DIR=/path/to/nakama-binary-dir server/test/run_local.sh   # needs Postgres on :5432
python3 server/test/smoke.py                                      # prints SMOKE PASSED
```

## Moderation and App Store rules

Apple requires, for apps with user-generated content: a filter, a way to report
and to block, and a way to reach the developer. Clan chat and names are filtered
on the server, every player and message can be reported and blocked in the
game, and repeated reports mute a player automatically (3 reporters: 1 day,
6 reporters: 7 days; 3 name reports reset the name). Reports are kept in the
`reports` storage collection: look at them in the Nakama console
(`ssh -L 7351:localhost:7351 you@server`, then http://localhost:7351).
Account deletion is in Settings › Account, as Apple requires.
