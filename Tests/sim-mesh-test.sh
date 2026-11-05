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

DT=$(xcrun simctl list devicetypes | grep -E "^iPhone 1[5-9] \(" | tail -1 | sed -E 's/.*\((com[^)]+)\).*/\1/')
RT=$(xcrun simctl list runtimes | grep -E "^iOS 26" | tail -1 | sed -E 's/.* - (com[^ ]+).*/\1/')
echo "device type: $DT  runtime: $RT"

boot() { # one at a time, retry once
  local u; u=$(xcrun simctl create "mesh-$1" "$DT" "$RT") || return 1
  eval "U_$1=$u"
  for attempt in 1 2 3; do
    xcrun simctl boot "$u" 2>/dev/null; xcrun simctl bootstatus "$u" -b >/dev/null 2>&1 && return 0
    echo "boot retry $attempt for $1"; xcrun simctl shutdown "$u" 2>/dev/null; sleep 10
  done
  return 1
}
for n in $NAMES; do boot $n || { echo "could not boot $n"; exit 1; }; done

stream() { xcrun simctl spawn "$(udid $1)" log stream --level info --style compact \
  --predicate 'subsystem == "com.swastik.districtmesh"' > "$OUT/$2.log" 2>&1 & }

for n in $NAMES; do
  u=$(udid $n)
  xcrun simctl install "$u" "$APP" || exit 1
  xcrun simctl privacy "$u" grant location-always "$BID" || true
  xcrun simctl privacy "$u" grant microphone "$BID" || true
  xcrun simctl location "$u" set 28.4744,77.5040 || true
  stream $n $n
done
sleep 3

launch() { # name group only [send]
  local args=(-district.onboarded YES -district.walkthroughDone YES -district.displayName "$1" -district.groupCode "$2" -meshTestOnly "$3")
  if [ -n "${4:-}" ]; then args+=(-meshTestSend "$4"); fi
  xcrun simctl launch "$(udid $1)" "$BID" "${args[@]}"
}
launch Bob   ci Alice,Carol
launch Carol ci Bob
launch Alice ci Bob "hello from alice"

echo "waiting for mesh + messages..."; sleep 60
xcrun simctl openurl "$(udid Alice)" districtmesh://sos
echo "SOS sent, waiting..."; sleep 25
for n in $NAMES; do xcrun simctl io "$(udid $n)" screenshot "$OUT/$n.png" >/dev/null 2>&1 || true; done

echo "group isolation: relaunching Carol in group 'other'"
xcrun simctl terminate "$(udid Carol)" "$BID"; sleep 3
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
for n in $NAMES; do xcrun simctl delete "$(udid $n)" >/dev/null 2>&1; done
[ $fail = 0 ] && echo "ALL MESH CHECKS PASSED" > "$OUT/RESULT"
exit $fail
