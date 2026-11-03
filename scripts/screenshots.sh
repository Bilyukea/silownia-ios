#!/bin/bash
# Скриншоты приложения в симуляторах iPhone и Apple Watch (запускается в Codemagic).
set -uo pipefail

OUT=screenshots
DD=build/dd
mkdir -p "$OUT"

echo "== Сборка для симуляторов"
xcodebuild build \
  -project Silownia.xcodeproj \
  -scheme Silownia \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build.log || exit 1

PHONE_APP=$(find "$DD/Build/Products" -maxdepth 2 -path "*iphonesimulator*" -name "Silownia.app" | head -1)
WATCH_APP=$(find "$DD/Build/Products" -maxdepth 2 -path "*watchsimulator*" -name "SilowniaWatch.app" | head -1)
echo "iPhone app: $PHONE_APP"
echo "Watch app:  $WATCH_APP"

# Выбор симуляторов: самая новая среда, предпочтительно iPhone Pro и часы 45/46 мм.
read -r PHONE WATCH < <(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devs = json.load(sys.stdin)["devices"]
def ver(rt):
    return [int(x) for x in re.findall(r"\d+", rt.split(".")[-1])]
def pick(os_name, prefixes):
    rts = sorted([rt for rt in devs if (os_name + "-") in rt and devs[rt]], key=ver, reverse=True)
    for rt in rts:
        for pref in prefixes:
            for d in devs[rt]:
                if d["name"].startswith(pref):
                    return d["udid"]
    return "none"
print(pick("iOS", ["iPhone 17 Pro", "iPhone 16 Pro", "iPhone 15 Pro", "iPhone"]),
      pick("watchOS", ["Apple Watch Series 11 (46mm)", "Apple Watch Series 10 (46mm)", "Apple Watch Series 9 (45mm)", "Apple Watch"]))
')
echo "PHONE=$PHONE WATCH=$WATCH"

shot() { # udid file
  sleep "${WAIT:-5}"
  xcrun simctl io "$1" screenshot "$OUT/$2.png" >/dev/null 2>&1 && echo "  ✓ $2" || echo "  ✗ $2"
}

if [ "$PHONE" != "none" ] && [ -n "$PHONE_APP" ]; then
  echo "== iPhone"
  xcrun simctl boot "$PHONE" 2>/dev/null || true
  xcrun simctl bootstatus "$PHONE" -b >/dev/null
  xcrun simctl status_bar "$PHONE" override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null || true
  xcrun simctl install "$PHONE" "$PHONE_APP"
  BID=pl.bilyukea.silownia
  for mode in light dark; do
    xcrun simctl ui "$PHONE" appearance "$mode" 2>/dev/null || true
    xcrun simctl launch --terminate-running-process "$PHONE" $BID -tab 0 >/dev/null; WAIT=6 shot "$PHONE" "iphone-$mode-1-strength"
    xcrun simctl launch --terminate-running-process "$PHONE" $BID -tab 1 >/dev/null; shot "$PHONE" "iphone-$mode-2-treadmill"
    xcrun simctl launch --terminate-running-process "$PHONE" $BID -tab 1 -openProgram B >/dev/null; shot "$PHONE" "iphone-$mode-3-program-b"
    xcrun simctl launch --terminate-running-process "$PHONE" $BID -tab 2 >/dev/null; shot "$PHONE" "iphone-$mode-4-settings"
  done
else
  echo "Симулятор iPhone не найден"
fi

if [ "$WATCH" != "none" ] && [ -n "$WATCH_APP" ]; then
  echo "== Apple Watch"
  xcrun simctl boot "$WATCH" 2>/dev/null || true
  xcrun simctl bootstatus "$WATCH" -b >/dev/null
  xcrun simctl install "$WATCH" "$WATCH_APP"
  WID=pl.bilyukea.silownia.watchkitapp
  W="-screenshots YES"
  xcrun simctl launch --terminate-running-process "$WATCH" $WID $W >/dev/null; WAIT=8 shot "$WATCH" "watch-1-start"
  xcrun simctl launch --terminate-running-process "$WATCH" $WID $W -demo YES -demoPage 0 >/dev/null; WAIT=7 shot "$WATCH" "watch-2-main"
  xcrun simctl launch --terminate-running-process "$WATCH" $WID $W -demo YES -demoPending YES -demoPage 0 >/dev/null; WAIT=7 shot "$WATCH" "watch-3-main-switch"
  xcrun simctl launch --terminate-running-process "$WATCH" $WID $W -demo YES -demoPage 1 >/dev/null; WAIT=7 shot "$WATCH" "watch-4-chart"
  xcrun simctl launch --terminate-running-process "$WATCH" $WID $W -demo YES -demoPage 2 >/dev/null; WAIT=7 shot "$WATCH" "watch-5-program"
else
  echo "Симулятор Apple Watch не найден"
fi

ls -la "$OUT"
cd "$OUT" && zip -q ../screenshots.zip ./*.png
