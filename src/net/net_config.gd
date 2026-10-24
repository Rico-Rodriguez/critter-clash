extends RefCounted
## Where the game server lives (see server/README.md). With HOST empty the
## game never goes online and every social screen says so.

## The box-hosted test server (see server/README.md). Its tunnel address changes
## when it restarts, so the game also reads CONFIG_URL at sign-in and follows it.
const HOST := "z0fc85.wormhole.bar"
const PORT := 443
const SSL := true
## Nakama's socket.server_key from the server's .env (not a secret: it only
## lets a client make or sign in to an account).
const SERVER_KEY := "devkey"

## Optional JSON {"url": "https://host[:port]", "key": "server key"} read at
## sign-in, so a moved server needs no new build. "" turns it off.
## The same file through the GitHub API, which is not cached like raw.
const CONFIG_API := "https://api.github.com/repos/Rico-Rodriguez/critter-clash/contents/server.json?ref=test-server"
const CONFIG_URL := "https://raw.githubusercontent.com/Rico-Rodriguez/critter-clash/test-server/server.json"

## Every request gives up after this many seconds, so a dead network never
## holds a screen.
const TIMEOUT := 12.0

## Where players write about accounts and other players (Apple asks apps with
## chat to show one). Shown under Profile › Account when set.
const SUPPORT := ""
