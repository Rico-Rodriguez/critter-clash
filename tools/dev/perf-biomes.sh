#!/bin/bash
# Frame budget of the biome zones: runs tools/dev/perf.sh's capture for each
# zone and scene, prints one line per run, and fails when a run is over budget.
#   draw calls p95 <= DRAWS (default 700), triangles avg <= PRIMS (450000: the Barrow hunt itself sits at about 440000, main.gd warns at 400000) and max <= 1.2 x PRIMS,
#   headless frame ms avg <= MS (default 10: script cost on this box's CPU, a
#   ceiling for the phone, not a phone number).
# Usage: [DRAWS=700 PRIMS=450000 MS=10 FRAMES=90] tools/dev/perf-biomes.sh [zones] [scenes]
#   zones: comma list, default frost,swamp.   scenes: default hunt,busy,boss
# One Godot at a time (slow on the software GPU: ~3-6 minutes per zone and scene).
D="$(cd "$(dirname "$0")" && pwd)"
ZONES="${1:-frost,swamp}"; SCENES="${2:-hunt,busy,boss}"
DRAWS="${DRAWS:-700}"; PRIMS="${PRIMS:-450000}"; MS="${MS:-10}"; FRAMES="${FRAMES:-90}"
OUT="${TMPDIR:-/tmp}/perf-biomes"; mkdir -p "$OUT"
fail=0
printf "%-8s %-6s %9s %9s %10s %10s %9s\n" zone scene draws_p95 draws_max prims_avg prims_max frame_ms
for z in ${ZONES//,/ }; do
	for s in ${SCENES//,/ }; do
		RES=590x1278 "$D/perf.sh" "$s" "$z" auto "$FRAMES" > "$OUT/$z-$s.log" 2>&1
		line=$(grep -E "^PERF draws" "$OUT/$z-$s.log" | tail -1)
		ms=$(grep -E "^PERF frame ms" "$OUT/$z-$s.log" | head -1 | sed -E 's/.*avg=([0-9.]+).*/\1/')
		p95=$(echo "$line" | sed -E 's/.*p95=([0-9.]+).*/\1/'); dmax=$(echo "$line" | sed -E 's/^PERF draws avg=[0-9.]+ p95=[0-9.]+ max=([0-9.]+).*/\1/')
		pmax=$(echo "$line" | sed -E 's/.*prims avg=[0-9.]+ max=([0-9.]+).*/\1/')
		pavg=$(echo "$line" | sed -E 's/.*prims avg=([0-9.]+) max=.*/\1/')
		printf "%-8s %-6s %9s %9s %10s %10s %9s\n" "$z" "$s" "${p95:-?}" "${dmax:-?}" "${pavg:-?}" "${pmax:-?}" "${ms:-?}"
		if grep -q "SCRIPT ERROR" "$OUT/$z-$s.log" || [ -z "$line" ] || [ -z "$ms" ]; then echo "  PERF FAILED: no numbers or a script error (log $OUT/$z-$s.log)"; fail=1; continue; fi
		awk -v a="$p95" -v b="$DRAWS" 'BEGIN{exit !(a>b)}' && { echo "  OVER BUDGET: draw calls p95 $p95 > $DRAWS"; fail=1; }
		awk -v a="$pavg" -v b="$PRIMS" 'BEGIN{exit !(a>b)}' && { echo "  OVER BUDGET: triangles avg $pavg > $PRIMS"; fail=1; }
		awk -v a="$pmax" -v b="$PRIMS" 'BEGIN{exit !(a>b*1.2)}' && { echo "  OVER BUDGET: triangles max $pmax > 1.2 x $PRIMS"; fail=1; }
		awk -v a="$ms" -v b="$MS" 'BEGIN{exit !(a>b)}' && { echo "  OVER BUDGET: frame ${ms} ms > $MS"; fail=1; }
	done
done
[ $fail -eq 0 ] && echo "PERF BUDGET PASSED" || echo "PERF BUDGET FAILED"
exit $fail
