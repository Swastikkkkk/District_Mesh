#!/usr/bin/env bash
# End-to-end mesh test on iOS simulators, using the real MultipeerConnectivity stack.
#
#   Alice <-> Bob <-> Carol      group "ci", forced into a chain (Alice and Carol never link)
#   then Carol relaunches in group "other" and must not reconnect.
#
# Checks: discovery + encrypted session, chat, 2-hop relay Alice -> Bob -> Carol,
# SOS flood over 2 hops via the districtmesh://sos deep link, group isolation.
set -uo pipefail

APP="$1"                      # path to DistrictMesh.app (Debug, iphonesimulator)
OUT="${2:-sim-out}"
BID=com.swastik.districtmesh
NAMES="Alice Bob Carol"
mkdir -p "$OUT"
udid() { eval echo "\$U_$1"; }

# Hard timeout for simulator commands (macOS has no `timeout`).
t() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

# Use simulators that ship with the runner image instead of creating new ones.
POOL=$(xcrun simctl list devices available | grep -E "^ +iPhone" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' | head -3)
[ "$(echo "$POOL" | wc -l | tr -d ' ')" = 3 ] || { echo "need 3 iPhone simulators"; xcrun simctl list devices available; exit 1; }
i=0; for u in $POOL; do set -- $NAMES; shift $i; eval "U_$1=$u"; i=$((i+1)); done
for n in $NAMES; do
  u=$(udid $n); echo "booting $n ($u)"
  t 60 xcrun simctl shutdown "$u" 2>/dev/null
  t 120 xcrun simctl boot "$u" || echo "boot cmd returned non-zero for $n"
  t 300 xcrun simctl bootstatus "$u" -b >/dev/null || { echo "$n never finished booting"; exit 1; }
  echo "$n booted"
done

stream() { xcrun simctl spawn "$(udid $1)" log stream --level info --style compact \
  --predicate 'subsystem == "com.swastik.districtmesh"' > "$OUT/$2.log" 2>&1 & }

for n in $NAMES; do
  u=$(udid $n)
  t 180 xcrun simctl install "$u" "$APP" || { echo "install failed on $n"; exit 1; }
  xcrun simctl privacy "$u" grant location-always "$BID" || true
  xcrun simctl privacy "$u" grant microphone "$BID" || true
  xcrun simctl location "$u" set 28.4744,77.5040 || true
  stream $n $n
done
sleep 3

launch() { # name group only [send]
  local args=(-district.onboarded YES -district.walkthroughDone YES -district.displayName "$1" -district.groupCode "$2" -meshTestOnly "$3")
  if [ -n "${4:-}" ]; then args+=(-meshTestSend "$4"); fi
  t 120 xcrun simctl launch "$(udid $1)" "$BID" "${args[@]}"
}
launch Bob   ci Alice,Carol
launch Carol ci Bob
launch Alice ci Bob "hello from alice"

echo "waiting for mesh + messages..."; sleep 60
t 60 xcrun simctl openurl "$(udid Alice)" districtmesh://sos
echo "SOS sent, waiting..."; sleep 25
for n in $NAMES; do t 30 xcrun simctl io "$(udid $n)" screenshot "$OUT/$n.png" >/dev/null 2>&1 || true; done

echo "group isolation: relaunching Carol in group 'other'"
t 60 xcrun simctl terminate "$(udid Carol)" "$BID"; sleep 3
stream Carol Carol-other
launch Carol other Bob
sleep 30

kill $(jobs -p) 2>/dev/null; sleep 1

fail=0
check() { if grep -qE "$3" "$OUT/$2.log"; then r=PASS; else r=FAIL; fi
  if [ "$1" = not ]; then [ $r = PASS ] && r=FAIL || r=PASS; fi
  echo "$r  $4"; [ $r = FAIL ] && fail=1; return 0; }
check is  Bob         "Connected: Alice"              "Bob connects to Alice"
check is  Bob         "Connected: Carol"              "Bob connects to Carol"
check not Alice       "Connected: Carol"              "Alice and Carol never link directly (chain forced)"
check is  Bob         "Message from Alice via Alice"  "Bob receives Alice's chat (1 hop)"
check is  Carol       "Message from Alice via Bob"    "Carol receives Alice's chat relayed by Bob (2 hops)"
check not Carol       "Message from Alice via Alice"  "No impossible direct path"
check is  Carol       "SOS from Alice"                "Carol gets Alice's SOS over 2 hops"
check not Carol-other "Connected:"                    "Different group never connects"

for f in Alice Bob Carol Carol-other; do echo "--- $f"; grep -vE "^Filtering|^Timestamp" "$OUT/$f.log" | tail -15; done
for n in $NAMES; do t 60 xcrun simctl shutdown "$(udid $n)" >/dev/null 2>&1; done
[ $fail = 0 ] && echo "ALL MESH CHECKS PASSED" > "$OUT/RESULT"
exit $fail
