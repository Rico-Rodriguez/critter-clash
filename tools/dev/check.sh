#!/bin/bash
# The gate every change must pass before commit:
#   1. re-import (also refreshes the class_name cache after new scripts)
#   2. compile every script, scene and shader
#   3. autopilot hunts: knight, mage, barbarian must mostly win
#   4. an idle hero must lose
# Usage: tools/dev/check.sh [--quick]
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
LOG="${TMPDIR:-/tmp}/barrowfall-check"
mkdir -p "$LOG"
fail=0
timeout 900 "$D/godot.sh" --import --quit > "$LOG/import.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error" -A1 "$LOG/import.log" | head -20
timeout 300 "$D/godot.sh" -- --check > "$LOG/compile.log" 2>&1
grep -E "CHECK|FAILED|SCRIPT ERROR" -A1 "$LOG/compile.log" | head -20
grep -q "CHECK .* OK" "$LOG/compile.log" || fail=1
timeout 300 "$D/godot.sh" -- --test > "$LOG/test.log" 2>&1
grep -E "FAIL|SCRIPT ERROR|TESTS" "$LOG/test.log" | head -20
grep -q "TESTS PASSED" "$LOG/test.log" || fail=1
if [ "${1:-}" != "--quick" ]; then
	timeout 1500 "$D/godot.sh" --fixed-fps 60 -- --bot --hero=knight,mage,barbarian,ranger > "$LOG/bot.log" 2>&1
	grep -E "^BOT|SCRIPT ERROR" "$LOG/bot.log" | cut -c1-150
	grep -q "BOT DONE PASS" "$LOG/bot.log" || fail=1
	grep -q "SCRIPT ERROR" "$LOG/bot.log" && fail=1
	[ "$(grep -c 'win=true' "$LOG/bot.log")" -ge 2 ] || fail=1
	timeout 900 "$D/godot.sh" --fixed-fps 60 -- --bot --zone=depths --hero=knight,mage > "$LOG/depths.log" 2>&1
	grep -E "^BOT|SCRIPT ERROR" "$LOG/depths.log" | cut -c1-150
	grep -q "BOT DONE PASS" "$LOG/depths.log" || fail=1
	grep -q "SCRIPT ERROR" "$LOG/depths.log" && fail=1
	[ "$(grep -c 'win=true' "$LOG/depths.log")" -ge 1 ] || fail=1
	timeout 900 "$D/godot.sh" --fixed-fps 60 -- --bot --mode=trial --hero=knight,mage > "$LOG/trial.log" 2>&1
	grep -E "^BOT|SCRIPT ERROR" "$LOG/trial.log" | cut -c1-150
	grep -q "BOT DONE PASS" "$LOG/trial.log" || fail=1
	grep -q "SCRIPT ERROR" "$LOG/trial.log" && fail=1
	[ "$(grep -c 'win=true' "$LOG/trial.log")" -ge 1 ] || fail=1
	timeout 600 "$D/godot.sh" --fixed-fps 60 -- --bot --hero=knight --idle > "$LOG/idle.log" 2>&1
	grep -E "^BOT" "$LOG/idle.log" | cut -c1-110
	grep -q "BOT DONE PASS" "$LOG/idle.log" || fail=1
fi
if [ $fail -eq 0 ]; then echo "CHECKS PASSED"; else echo "CHECKS FAILED (logs in $LOG)"; fi
exit $fail
