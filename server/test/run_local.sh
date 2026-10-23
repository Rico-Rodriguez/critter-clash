#!/bin/bash
# Copies the modules into a local Nakama's data dir and restarts it, for the
# smoke test. Usage: NAKAMA_DIR=/path/to/nakama server/test/run_local.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
N="${NAKAMA_DIR:?set NAKAMA_DIR to the folder holding the nakama binary}"
DB="${NAKAMA_DB:-nakama:localdev@127.0.0.1:5432/nakama}"
pkill -x nakama || true
sleep 1
mkdir -p "$N/data/modules"
cp "$ROOT"/server/nakama/modules/*.lua "$N/data/modules/"
sed "s#/nakama/data/modules#$N/data/modules#" "$ROOT/server/nakama/gravelight.yml" > "$N/local.yml"
"$N/nakama" migrate up --database.address "$DB" > /dev/null 2>&1
cd "$N"
nohup "$N/nakama" --config "$N/local.yml" --database.address "$DB" --socket.server_key devkey \
	--runtime.http_key devhttp --console.username admin --console.password 'Passw0rd!' \
	--data_dir "$N/data" > "$N/nakama.log" 2>&1 &
until grep -q "Startup done" "$N/nakama.log" 2>/dev/null; do
	if grep -q '"level":"fatal"' "$N/nakama.log" 2>/dev/null; then tail -5 "$N/nakama.log"; exit 1; fi
	sleep 0.5
done
echo "nakama up"
