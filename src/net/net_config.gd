extends RefCounted
## Where the game server lives (see server/README.md). With HOST empty the
## game never goes online and every social screen says so.

const HOST := ""
const PORT := 443
const SSL := true
## Nakama's socket.server_key from the server's .env (not a secret: it only
## lets a client make or sign in to an account).
const SERVER_KEY := "devkey"

## Every request gives up after this many seconds, so a dead network never
## holds a screen.
const TIMEOUT := 8.0

## Where players write about accounts and other players (Apple asks apps with
## chat to show one). Shown under Profile › Account when set.
const SUPPORT := ""
