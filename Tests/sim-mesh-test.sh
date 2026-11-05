#!/usr/bin/env bash
# End-to-end mesh test on iOS simulators, using the real MultipeerConnectivity stack.
#
#   Alice <-> Bob <-> Carol      group "ci", forced into a chain (Alice and Carol never link)
#   Dave                         group "other", must never connect to anyone
#
# Checks: discovery + encrypted session, chat, 2-hop relay Alice -> Bob -> Carol,
# SOS flood over 2 hops via the districtmesh://sos deep link, group isolation.
set -uo pipefail

APP="$1"                      # path to DistrictMesh.app (Debug, iphonesimulator)
OUT="${2:-sim-out}"
BID=com.swastik.districtmesh
mkdir -p "$OUT"

DT=$(xcrun simctl list devicetypes | grep -E "^iPhone 1[5-9] \(" | tail -1 | sed -E 's/.*\((com[^)]+)\).*/\1/')
RT=$(xcrun simctl list runtimes | grep -E "^iOS 26" | tail -1 | sed -E 's/.* - (com[^ ]+).*/\1/')
echo "device type: $DT  runtime: $RT"

declare -A UDID
for n in Alice Bob Carol Dave; do
  UDID[$n]=$(xcrun simctl create "mesh-$n" "$DT" "$RT")
  xcrun simctl boot "${UDID[$n]}"
done
for n in Alice Bob Carol Dave; do xcrun simctl bootstatus "${UDID[$n]}" -b >/dev/null; done

for n in Alice Bob Carol Dave; do
  u=${UDID[$n]}
  xcrun simctl install "$u" "$APP"
  xcrun simctl privacy "$u" grant location-always "$BID" || true
  xcrun simctl privacy "$u" grant microphone "$BID" || true
  xcrun simctl location "$u" set 28.4744,77.5040 || true
  xcrun simctl spawn "$u" log stream --level info --style compact \
    --predicate 'subsystem == "com.swastik.districtmesh"' > "$OUT/$n.log" 2>&1 &
done
sleep 3

launch() { # name group only [send]
  local args=(-district.onboarded YES -district.walkthroughDone YES -district.displayName "$1" -district.groupCode "$2" -meshTestOnly "$3")
  [ -n "${4:-}" ] && args+=(-meshTestSend "$4")
  xcrun simctl launch "${UDID[$1]}" "$BID" "${args[@]}"
}
launch Bob   ci    Alice,Carol
launch Carol ci    Bob
launch Alice ci    Bob "hello from alice"
launch Dave  other Alice,Bob,Carol

echo "waiting for mesh + messages..."; sleep 60
xcrun simctl openurl "${UDID[Alice]}" districtmesh://sos
echo "SOS sent, waiting..."; sleep 25

for n in Alice Bob Carol Dave; do xcrun simctl io "${UDID[$n]}" screenshot "$OUT/$n.png" >/dev/null 2>&1 || true; done
kill $(jobs -p) 2>/dev/null; sleep 1

fail=0
check() { if grep -qE "$3" "$OUT/$2.log"; then r=PASS; else r=FAIL; fi; [ "$1" = not ] && { [ $r = PASS ] && r=FAIL || r=PASS; }; echo "$r  $4"; [ $r = FAIL ] && fail=1; }
check is  Bob   "Connected: Alice"                 "Bob connects to Alice"
check is  Bob   "Connected: Carol"                 "Bob connects to Carol"
check not Alice "Connected: Carol"                 "Alice and Carol never link directly (chain forced)"
check is  Bob   "Message from Alice via Alice"     "Bob receives Alice's chat (1 hop)"
check is  Carol "Message from Alice via Bob"       "Carol receives Alice's chat relayed by Bob (2 hops)"
check is  Carol "SOS from Alice"                   "Carol gets Alice's SOS over 2 hops"
check not Dave  "Connected:"                       "Different group never connects"
check not Carol "Message from Alice via Alice"     "No impossible direct path"

for n in Alice Bob Carol Dave; do echo "--- $n"; grep -vE "^Filtering|^Timestamp" "$OUT/$n.log" | tail -15; done
for n in Alice Bob Carol Dave; do xcrun simctl delete "${UDID[$n]}" >/dev/null 2>&1; done
exit $fail
