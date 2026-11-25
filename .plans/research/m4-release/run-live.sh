#!/bin/sh
# Serve each render on loopback and run the release's live check against it.
cd "$(dirname "$0")"
check=../../.plans/research/m4-release/live-check.sh
python3 -I -m http.server 8765 --bind 127.0.0.1 --directory . >/dev/null 2>&1 &
srv=$!
trap 'kill $srv 2>/dev/null' EXIT
i=0; until curl -s -o /dev/null http://127.0.0.1:8765/ || [ $i -ge 50 ]; do i=$((i+1)); sleep 0.1; done
for r in v010 main plant-pages plant-clone; do
  echo "== $r"
  sh "$check" "http://127.0.0.1:8765/$r/" v0.1.0
  echo "exit $?"
done
