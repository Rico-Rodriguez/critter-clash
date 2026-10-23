#!/usr/bin/env python3
"""Fills a local test server with a lively clan for screenshots: six hunters
with progress on the leaderboard, the clan "Lantern Watch" with chat and raid
hits. Prints the friend code of its leader, for `--ref=` in captures.

    python3 server/test/seed_demo.py [http://127.0.0.1:7350] [server_key]
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


class P:
    def __init__(self, name):
        basic = base64.b64encode((KEY + ":").encode()).decode()
        r = requests.post(HOST + "/v2/account/authenticate/device?create=true",
                          json={"id": uuid.uuid4().hex + uuid.uuid4().hex[:8]}, headers={"Authorization": "Basic " + basic})
        self.token = r.json()["token"]
        self.h = {"Authorization": "Bearer " + self.token}
        self.code = self.rpc("bootstrap")["code"]
        self.rpc("set_name", {"name": name})
        self.name = name

    def rpc(self, n, p=None):
        r = requests.post(HOST + "/v2/rpc/" + n, data=json.dumps(json.dumps(p or {})), headers=self.h)
        return json.loads(r.json().get("payload") or "{}")


people = [("Rico", "knight", 41, 5200), ("Manz", "mage", 37, 4410), ("Kenpachi", "barbarian", 44, 6100),
          ("Lyra", "ranger", 29, 3020), ("Old Tom", "knight", 22, 1900), ("Vex", "mage", 33, 3880)]
ps = []
for name, hero, combat, power in people:
    p = P(name)
    p.rpc("report_progress", {"hunts": 3, "wins": 2, "combat": combat, "power": power, "hero": hero, "best_tier_won": 1})
    ps.append(p)
clan = ps[0].rpc("clan_create", {"name": "Lantern Watch %02d" % (int(time.time()) % 100), "desc": "Raids every week. Be kind, hunt hard.", "open": True, "badge": 4})
for p in ps[1:]:
    requests.post(HOST + "/v2/group/%s/join" % clan["id"], json={}, headers=p.h)
lines = [(1, {"t": "text", "body": "Raid boss is at half already!"}), (2, {"t": "text", "body": "Got a Kingsgold glow drop on Veteran, finally"}),
         (0, {"t": "emote", "id": "gg"}), (3, {"t": "text", "body": "Anyone up for the Long Road later?"}),
         (2, {"t": "invite", "party": "demo", "mode": "horde", "zone": "barrow", "tier": 1, "hero": "barbarian"})]
socks = {}
for i, content in lines:
    if i not in socks:
        ws = websocket.create_connection(HOST.replace("http", "ws") + "/ws?lang=en&token=" + ps[i].token, timeout=5)
        ws.send(json.dumps({"cid": "1", "channel_join": {"target": clan["id"], "type": 3, "persistence": True, "hidden": False}}))
        socks[i] = (ws, json.loads(ws.recv())["channel"]["id"])
    ws, ch = socks[i]
    ws.send(json.dumps({"cid": "2", "channel_message_send": {"channel_id": ch, "content": json.dumps(content)}}))
    ws.recv()
    time.sleep(1.1)
for p, dmg in zip(ps, [18000, 15000, 20000, 9000]):
    p.rpc("raid_hit", {"damage": dmg, "tier": 1})
print(json.dumps({"ref": ps[0].code, "clan": clan["name"]}))
