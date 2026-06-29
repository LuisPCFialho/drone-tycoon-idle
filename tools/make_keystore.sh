#!/usr/bin/env bash
set -euo pipefail
KEYTOOL="${KEYTOOL:-keytool}"
OUT="keystore/dronetycoon.keystore"; mkdir -p keystore
[ -f "$OUT" ] && { echo "exists: $OUT"; exit 0; }
"$KEYTOOL" -genkeypair -v -keystore "$OUT" -alias dronetycoon -keyalg RSA -keysize 2048 \
  -validity 10000 -storepass drone123 -keypass drone123 \
  -dname "CN=Drone Tycoon, OU=Games, O=LuisPCFialho, C=PT"
