#!/usr/bin/env python3
"""End-to-end check of the Gravelight server rules against a running Nakama.

Makes throwaway accounts and walks every feature the game uses: names, friend
codes and referrals, the reward inbox, milestones, clans, filtered chat,
reports and mutes, the clan raid, parties, cloud saves, transfer codes and
account deletion.

    pip install requests websocket-client
    python3 server/test/smoke.py [http://127.0.0.1:7350] [server_key]

Run it against a local or staging server, never production: it makes accounts.
"""
import base64
import json
import sys
import time
import uuid

import requests
import websocket

HOST = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:7350"
KEY = sys.argv[2] if len(sys.argv) > 2 else "devkey"
fails = 0


def ok(name, cond, extra=""):
    global fails
    print(("OK   " if cond else "FAIL ") + name + (("  " + str(extra)) if extra and not cond else ""))
    if not cond:
        fails += 1


class Player:
    def __init__(self, key=None):
        self.key = key or uuid.uuid4().hex + uuid.uuid4().hex[:8]
        self.auth()

    def auth(self):
        basic = base64.b64encode((KEY + ":").encode()).decode()
        r = requests.post(HOST + "/v2/account/authenticate/device?create=true",
                          json={"id": self.key}, headers={"Authorization": "Basic " + basic})
        r.raise_for_status()
        self.token = r.json()["token"]
        self.h = {"Authorization": "Bearer " + self.token}
        self.me = requests.get(HOST + "/v2/account", headers=self.h).json()
        self.id = self.me["user"]["id"]

    def rpc(self, name, payload=None):
        r = requests.post(HOST + "/v2/rpc/" + name, data=json.dumps(json.dumps(payload or {})), headers=self.h)
        if r.status_code != 200:
            return None, r.json().get("message", r.text)
        return json.loads(r.json().get("payload") or "{}"), None

    def get(self, path):
        return requests.get(HOST + path, headers=self.h).json()

    def post(self, path, body=None):
        return requests.post(HOST + path, json=body or {}, headers=self.h)

    def socket(self):
        ws = websocket.create_connection(HOST.replace("http", "ws") + "/ws?lang=en&status=true&token=" + self.token, timeout=5)
        return Sock(ws)


class Sock:
    def __init__(self, ws):
        self.ws = ws
        self.cid = 0
        self.inbox = []

    def call(self, msg):
        self.cid += 1
        msg["cid"] = str(self.cid)
        self.ws.send(json.dumps(msg))
        while True:
            m = json.loads(self.ws.recv())
            if m.get("cid") == str(self.cid):
                return m
            self.inbox.append(m)

    def wait(self, key, secs=3.0, match=None):
        hit = lambda m: key in m and (match is None or match(m[key]))
        for m in self.inbox:
            if hit(m):
                self.inbox.remove(m)
                return m
        end = time.time() + secs
        while time.time() < end:
            try:
                m = json.loads(self.ws.recv())
            except Exception:
                return None
            if hit(m):
                return m
            self.inbox.append(m)
        return None


def kinds(grants):
    out = []
    for g in grants:
        out += [x["kind"] for x in g["grants"]]
    return out


# --- Accounts and names -----------------------------------------------------
a = Player()
b = Player()
boot, err = a.rpc("bootstrap")
ok("bootstrap gives a 6 letter code", boot and len(boot["code"]) == 6, err)
ok("new account can redeem", boot and boot["can_redeem"] is True)
code_a = boot["code"]
ok("code is the username", a.get("/v2/account")["user"]["username"] == code_a)
res, err = a.rpc("set_name", {"name": "Rico Suave"})
ok("good name accepted", res and res["name"] == "Rico Suave", err)
res, err = a.rpc("set_name", {"name": "fuuuck you"})
ok("rude name refused", res is None and "another name" in err, err)
res, err = a.rpc("set_name", {"name": "visit www.spam.com"})
ok("link name refused", res is None, err)
r = requests.put(HOST + "/v2/account", json={"display_name": "sneaky"}, headers=a.h)
ok("direct account update blocked", r.status_code != 200, r.status_code)
b.rpc("bootstrap")
b.rpc("set_name", {"name": "Manz"})

# --- Referrals ---------------------------------------------------------------
res, err = b.rpc("redeem", {"code": "ZZZZZZ"})
ok("unknown code refused", res is None, err)
res, err = a.rpc("redeem", {"code": code_a})
ok("own code refused", res is None and "own code" in err, err)
red, err = b.rpc("redeem", {"code": code_a.lower()})
ok("friend code redeemed", red and red["ok"], err)
res, err = b.rpc("redeem", {"code": code_a})
ok("second redeem refused", res is None, err)
res, err = a.rpc("redeem", {"code": b.rpc("bootstrap")[0]["code"]})
ok("no referring your recruiter back", res is None, err)
g_b = b.rpc("list_grants")[0]["grants"]
ok("recruit gets welcome gift", "chest" in kinds(g_b) and "gold" in kinds(g_b), g_b)
g_a = a.rpc("list_grants")[0]["grants"]
ok("recruiter gets thank-you", len(g_a) == 1 and kinds(g_a) == ["gold"], g_a)
friends = a.get("/v2/friend")
ok("recruit and recruiter are friends", any(f["user"]["id"] == b.id and f.get("state", 0) == 0 for f in friends.get("friends", [])), friends)
ok("recruit sees recruiter's name", red["friend"] == "Rico Suave", red)
b.rpc("ack_grants", {"ids": [g["id"] for g in g_b]})
ok("acked grants are gone", not b.rpc("list_grants")[0]["grants"])

# Milestones: the recruit plays; progress is capped by time so a hacked save
# can't jump to 500 hunts.
res, _ = b.rpc("report_progress", {"hunts": 500, "wins": 500, "combat": 30, "power": 900, "hero": "knight", "best_tier_won": 1})
prof = b.rpc("profiles", {"ids": [b.id]})[0]["profiles"][b.id]
ok("hunt count is capped", prof["hunts"] < 500, prof)
time.sleep(10.5)
b.rpc("report_progress", {"hunts": 6, "wins": 4, "combat": 30, "power": 900, "hero": "knight", "best_tier_won": 1})
g_a = a.rpc("list_grants")[0]["grants"]
reasons = [g["reason"] for g in g_a]
ok("recruiter paid for milestones", reasons.count("milestone") >= 1, reasons)
ok("first recruit earns the kinship glow", any(x.get("glow") == "kinship" for g in g_a for x in g["grants"]), g_a)
rec = a.rpc("recruits")[0]
ok("recruits list shows the friend", rec["list"][0]["name"] == "Manz" and rec["list"][0]["done"].get("hunts5"), rec)
lb = a.get("/v2/leaderboard/power?limit=10")
ok("leaderboard has the recruit", any(x["owner_id"] == b.id for x in lb.get("records", [])), lb)

# --- Clans -------------------------------------------------------------------
r = a.post("/v2/group", {"name": "Direct", "open": True})
ok("direct group create blocked", r.status_code != 200)
clan_name = "Lantern %04d" % (int(time.time()) % 10000)
res, err = a.rpc("clan_create", {"name": clan_name, "desc": "Chill clan, all welcome", "open": True, "badge": 3})
ok("clan created", res and res["id"], err)
clan = res["id"]
res, err = a.rpc("clan_create", {"name": "Second"})
ok("one clan per player", res is None, err)
res, err = b.rpc("clan_create", {"name": "shit clan"})
ok("rude clan name refused", res is None, err)
r = b.post("/v2/group/%s/join" % clan)
ok("open clan joined", r.status_code == 200, r.text)
ok("bootstrap shows clan", b.rpc("bootstrap")[0]["clan"]["id"] == clan)
c = Player()
c.rpc("bootstrap")
c.rpc("set_name", {"name": "Kenpachi"})
res, err = a.rpc("clan_edit", {"desc": "Daily raids", "min_combat": 40})
ok("leader edits clan", res and res["ok"], err)
r = c.post("/v2/group/%s/join" % clan)
ok("min combat enforced", r.status_code != 200, r.text)
found = c.get("/v2/group?name=" + clan_name.replace(" ", "%20") + "%25&limit=10")
ok("clan search finds it", any(g["id"] == clan for g in found.get("groups", [])), found)

# --- Chat ----------------------------------------------------------------------
sa = a.socket()
sb = b.socket()
ja = sa.call({"channel_join": {"target": clan, "type": 3, "persistence": True, "hidden": False}})
jb = sb.call({"channel_join": {"target": clan, "type": 3, "persistence": True, "hidden": False}})
ch = ja["channel"]["id"]
ok("joined clan chat", ch == jb["channel"]["id"])
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "text", "body": "hello you fucking legends"})}})
ok("message acked", "channel_message_ack" in m, m)
got = sb.wait("channel_message")
body = json.loads(got["channel_message"]["content"])["body"] if got else ""
ok("rude word masked", "fucking" not in body and "hello" in body, body)
time.sleep(1.1)
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "text", "body": "add me on discord abc#123"})}})
ok("contact details refused", "error" in m, m)
time.sleep(1.1)
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "emote", "id": "gg"})}})
m2 = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "emote", "id": "gg"})}})
ok("rate limited", "channel_message_ack" in m and "error" in m2, (m, m2))
time.sleep(1.1)
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "raid", "body": "fake system message"})}})
ok("players can't fake system lines", "error" in m, m)
hist = a.get("/v2/channel/%s?limit=20&forward=false" % ch)
ok("history kept", len(hist.get("messages", [])) >= 2, hist)

# --- Parties (co-op lobby) --------------------------------------------------------------
p = sa.call({"party_create": {"open": True, "max_size": 3}})
pid = p["party"]["party_id"]
time.sleep(1.1)
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "invite", "party": pid, "mode": "trial", "tier": 2, "zone": "barrow", "hero": "knight"})}})
ok("party invite posted", "channel_message_ack" in m, m)
inv = sb.wait("channel_message", match=lambda c: json.loads(c["content"]).get("t") == "invite")
ok("invite arrives", inv and json.loads(inv["channel_message"]["content"])["party"] == pid, inv)
sb.call({"party_join": {"party_id": pid}})
pres = sa.wait("party_presence_event")
ok("friend joins party", pres is not None, sa.inbox[-3:])
data = base64.b64encode(json.dumps({"x": 1.5, "z": -2.0}).encode()).decode()
sb.ws.send(json.dumps({"party_data_send": {"party_id": pid, "op_code": 2, "data": data}}))
pd = sa.wait("party_data")
ok("party data relayed", pd and pd["party_data"]["op_code"] in (2, "2"), pd)

# --- Reports and mutes ------------------------------------------------------------
reporters = [Player() for _ in range(3)]
for rp in reporters:
    rp.rpc("report", {"user_id": a.id, "reason": "chat", "message": "spam"})
time.sleep(1.1)
m = sa.call({"channel_message_send": {"channel_id": ch, "content": json.dumps({"t": "text", "body": "still here"})}})
ok("three reports mute", "error" in m and "muted" in json.dumps(m), m)
ok("bootstrap shows mute", a.rpc("bootstrap")[0]["muted_until"] > time.time())

# --- Clan raid --------------------------------------------------------------------------
st, err = b.rpc("raid_status")
ok("raid has a boss", st and st["boss"] and st["hp"] == st["max"], err)
hit, err = b.rpc("raid_hit", {"damage": 999999999, "tier": 0})
ok("raid hit capped", hit and st["max"] - hit["hp"] == 20000, (err, hit))
for _ in range(5):
    a.rpc("raid_hit", {"damage": 999999, "tier": 8})
    b.rpc("raid_hit", {"damage": 999999, "tier": 8})
st = b.rpc("raid_status")[0]
ok("raid boss falls", st["hp"] == 0 and st["fallen"] > 0, st)
ok("raiders rewarded", any(g["reason"] == "raid" for g in b.rpc("list_grants")[0]["grants"]))

# --- Saves, new phone, deletion ---------------------------------------------------------
save = json.dumps({"gold": 1234, "version": 6})
res, err = a.rpc("save_put", {"data": save, "hunts": 9})
ok("save stored", res and res["ok"], err)
ok("save read back", a.rpc("save_get")[0]["data"] == save)
t, err = a.rpc("transfer_make")
ok("transfer code made", t and len(t["code"]) == 8, err)
newphone = Player()
res, err = newphone.rpc("transfer_use", {"code": t["code"], "key": newphone.key})
ok("transfer used", res and res["ok"], err)
newphone.auth()
ok("new phone signs into the old account", newphone.id == a.id, (newphone.id, a.id))
a.auth()
ok("old phone still works", a.id == newphone.id)
res, err = c.rpc("transfer_use", {"code": t["code"], "key": c.key})
ok("transfer code single use", res is None, err)
gone = Player()
gid = gone.id
gone.rpc("delete_account")
again = Player(gone.key)
ok("deleted account is gone", again.id != gid)

print("SMOKE %s" % ("PASSED" if fails == 0 else "%d FAILED" % fails))
sys.exit(1 if fails else 0)
