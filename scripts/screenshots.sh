#!/usr/bin/env bash
# Capture portrait App Store screenshots for iPhone 16 Pro Max and iPad Pro 13-inch (M4).
# Boots one of those simulators at a time and shuts it down before the next. Leaves none booted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IPHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB"
IPHONE_NAME="mdview-shots iPhone 16 Pro Max"
IPAD_NAME="mdview-shots iPad Pro 13 (M4)"
SAMPLE_DIR="$ROOT/scripts/screenshot-samples"
IPHONE_OUT="$ROOT/docs/app-store/screenshots/iphone-6.9"
IPAD_OUT="$ROOT/docs/app-store/screenshots/ipad-13"
RUN_FILE="/tmp/mdview-screenshot-run.json"
BOOTED_UDIDS=""

cleanup() {
  status=$?
  rm -f "$RUN_FILE"
  for udid in $BOOTED_UDIDS; do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    wait_for_shutdown "$udid" || true
  done
  exit "$status"
}
trap cleanup EXIT

device_state() {
  python3 - "$1" <<'PY'
import json, subprocess, sys
udid = sys.argv[1]
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True)
for devices in json.loads(raw).get("devices", {}).values():
    for device in devices:
        if device.get("udid") == udid:
            print(device.get("state", "unknown"))
            raise SystemExit(0)
print("missing")
PY
}

wait_for_shutdown() {
  udid="$1"
  i=0
  state=""
  while [ "$i" -lt 90 ]; do
    state="$(device_state "$udid")"
    if [ "$state" = "Shutdown" ] || [ "$state" = "missing" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  echo "error: simulator $udid did not shut down (state: $state)" >&2
  return 1
}

forget_udid() {
  next=""
  for item in $BOOTED_UDIDS; do
    if [ "$item" != "$1" ]; then
      next="$next $item"
    fi
  done
  BOOTED_UDIDS="$next"
}

shutdown_device() {
  udid="$1"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  wait_for_shutdown "$udid"
  forget_udid "$udid"
}

boot_device() {
  udid="$1"
  state="$(device_state "$udid")"
  if [ "$state" != "Booted" ]; then
    xcrun simctl boot "$udid"
  fi
  xcrun simctl bootstatus "$udid" -b
  BOOTED_UDIDS="$BOOTED_UDIDS $udid"
}

lookup_device() {
  python3 - "$1" "$2" <<'PY'
import json, subprocess, sys
name, device_type = sys.argv[1], sys.argv[2]
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True)
for devices in json.loads(raw).get("devices", {}).values():
    for device in devices:
        if device.get("name") == name and device.get("deviceTypeIdentifier") == device_type:
            print(device.get("udid", ""))
            raise SystemExit(0)
PY
}

ensure_device() {
  name="$1"
  device_type="$2"
  udid="$(lookup_device "$name" "$device_type" || true)"
  if [ -z "$udid" ]; then
    udid="$(xcrun simctl create "$name" "$device_type" "$RUNTIME")"
  fi
  printf '%s\n' "$udid"
}

shutdown_if_booted() {
  udid="$(lookup_device "$1" "$2" || true)"
  if [ -n "$udid" ]; then
    state="$(device_state "$udid")"
    if [ "$state" = "Booted" ]; then
      echo "==> shutting down leftover $1"
      shutdown_device "$udid"
    fi
  fi
}

pick_runtime() {
  python3 - <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "available", "-j"], text=True)
found = []
for runtime in json.loads(raw).get("runtimes", []):
    ident = runtime.get("identifier", "")
    if not ident.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
        continue
    if runtime.get("isAvailable") is False:
        continue
    version = tuple(int(part) for part in str(runtime.get("version", "0")).split(".") if part.isdigit())
    found.append((version, ident))
if not found:
    sys.exit("error: no available iOS simulator runtime")
found.sort()
print(found[-1][1])
PY
}

inject_test_env() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import plistlib, sys
path, output, samples, udid = sys.argv[1:5]
with open(path, "rb") as handle:
    plist = plistlib.load(handle)

def device_root(identifier):
    home = __import__("os").path.expanduser("~")
    return home + "/Library/Developer/CoreSimulator/Devices/" + identifier

def sample_text(name):
    with open(__import__("os").path.join(samples, name), encoding="utf-8") as handle:
        return handle.read()

values = {
    "MDVIEW_SCREENSHOTS": "1",
    "MDVIEW_SCREENSHOT_DIR": output,
    "MDVIEW_SAMPLE_DIR": samples,
    "MDVIEW_SIMULATOR_UDID": udid,
    "MDVIEW_DEVICE_ROOT": device_root(udid),
    "MDVIEW_SAMPLE_CEDAR": sample_text("Cedar Trail.md"),
    "MDVIEW_SAMPLE_REVIEW": sample_text("Weekly Review.md"),
    "MDVIEW_SAMPLE_CHECKLIST": sample_text("Launch Checklist.md"),
}

def inject(node):
    if isinstance(node, dict):
        bundle = str(node.get("TestBundlePath", ""))
        if node.get("BlueprintName") == "mdviewUITests" or bundle.endswith("mdviewUITests.xctest"):
            for key in ("EnvironmentVariables", "TestingEnvironmentVariables"):
                env = node.get(key)
                if not isinstance(env, dict):
                    env = {}
                env.update(values)
                node[key] = env
        for child in node.values():
            inject(child)
    elif isinstance(node, list):
        for child in node:
            inject(child)

inject(plist)
with open(path, "wb") as handle:
    plistlib.dump(plist, handle)
PY
}

write_run_file() {
  python3 - "$RUN_FILE" "$1" "$SAMPLE_DIR" "$2" <<'PY'
import json, os, sys
path, output, samples, udid = sys.argv[1:5]
device_root = os.path.expanduser("~/Library/Developer/CoreSimulator/Devices/" + udid)
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "enabled": True,
            "output": output,
            "samples": samples,
            "udid": udid,
            "deviceRoot": device_root,
        },
        handle,
    )
PY
}

flatten_png() {
  file="$1"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/ { print $2 }')"
  if [ "$alpha" != "yes" ]; then
    return 0
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/mdview-flat.XXXXXX")"
  rm -f "$tmp"
  if sips -s format bmp "$file" --out "$tmp.bmp" >/dev/null 2>&1; then
    sips -s format png "$tmp.bmp" --out "$file" >/dev/null
    rm -f "$tmp.bmp"
  else
    sips -s format jpeg -s formatOptions 100 "$file" --out "$tmp.jpg" >/dev/null
    sips -s format png "$tmp.jpg" --out "$file" >/dev/null
    rm -f "$tmp.jpg"
  fi
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/ { print $2 }')"
  if [ "$alpha" = "yes" ]; then
    echo "error: $file still has an alpha channel" >&2
    return 1
  fi
}

collect_shots() {
  label="$1"
  outdir="$2"
  stage="$(mktemp -d "${TMPDIR:-/tmp}/mdview-shots.XXXXXX")"
  xcrun xcresulttool export attachments \
    --path "$ROOT/.derivedData/screenshot-$label.xcresult" \
    --output-path "$stage"
  python3 - "$stage" "$outdir" <<'PY'
import json, os, shutil, sys
stage, outdir = sys.argv[1:3]
wanted = [
    "01-rendered-light.png",
    "02-rendered-dark.png",
    "03-source.png",
    "04-find.png",
    "05-obsidian.png",
    "06-outline.png",
    "07-tasks.png",
]
with open(os.path.join(stage, "manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)

def walk(node):
    found = []
    if isinstance(node, dict):
        if "exportedFileName" in node:
            found.append(node)
        for value in node.values():
            found.extend(walk(value))
    elif isinstance(node, list):
        for value in node:
            found.extend(walk(value))
    return found

found = walk(manifest)
print(f"attachments {len(found)}")
for item in found:
    print(item.get("suggestedHumanReadableName"), "->", item.get("exportedFileName"))
os.makedirs(outdir, exist_ok=True)
for name in wanted:
    stem = name[:-4]
    match = None
    for item in found:
        label_name = str(item.get("suggestedHumanReadableName", ""))
        if name in label_name or stem in label_name:
            match = item
            break
    if match is None:
        sys.exit(f"error: missing attachment {name}")
    exported = os.path.basename(str(match["exportedFileName"]))
    hits = []
    for dirpath, _, files in os.walk(stage):
        if exported in files:
            hits.append(os.path.join(dirpath, exported))
    if not hits:
        sys.exit(f"error: exported file missing for {name}: {exported}")
    shutil.copyfile(hits[0], os.path.join(outdir, name))
PY
  rm -rf "$stage"
}

verify_shots() {
  kind="$1"
  dir="$2"
  names="01-rendered-light.png 02-rendered-dark.png 03-source.png 04-find.png 05-obsidian.png 06-outline.png 07-tasks.png"
  for name in $names; do
    file="$dir/$name"
    if [ ! -f "$file" ]; then
      echo "error: missing $file" >&2
      return 1
    fi
    flatten_png "$file"
    width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"
    echo "$file ${width}x${height}"
    ok=0
    if [ "$kind" = "iphone" ]; then
      if [ "$width" = "1320" ] && [ "$height" = "2868" ]; then ok=1; fi
      if [ "$width" = "1290" ] && [ "$height" = "2796" ]; then ok=1; fi
    else
      if [ "$width" = "2064" ] && [ "$height" = "2752" ]; then ok=1; fi
      if [ "$width" = "2048" ] && [ "$height" = "2732" ]; then ok=1; fi
    fi
    if [ "$ok" -ne 1 ]; then
      echo "error: $file is ${width}x${height}" >&2
      if [ "$kind" = "iphone" ]; then
        echo "error: iPhone screenshots must be 1320x2868 or 1290x2796" >&2
      else
        echo "error: iPad screenshots must be 2064x2752 or 2048x2732" >&2
      fi
      return 1
    fi
  done
}

run_device() {
  label="$1"
  udid="$2"
  outdir="$3"
  echo "==> $label ($udid)"
  boot_device "$udid"
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3
  xcrun simctl ui "$udid" appearance light
  xcrun simctl uninstall "$udid" us.par72.mdview >/dev/null 2>&1 || true
  mkdir -p "$outdir"
  rm -f "$outdir/hierarchy.txt"
  inject_test_env "$XCTESTRUN" "$outdir" "$SAMPLE_DIR" "$udid"
  write_run_file "$outdir" "$udid"
  rm -rf ".derivedData/screenshot-$label.xcresult"
  echo "==> UI test $label"
  if ! xcodebuild test-without-building \
    -xctestrun "$XCTESTRUN" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:mdviewUITests/ScreenshotTests \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -resultBundlePath "$ROOT/.derivedData/screenshot-$label.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    >"$ROOT/.derivedData/screenshot-test-$label.log" 2>&1; then
    echo "error: screenshot UI test failed for $label" >&2
    tail -n 160 "$ROOT/.derivedData/screenshot-test-$label.log" >&2
    return 1
  fi
  if grep -E -q "Test Case .* skipped" "$ROOT/.derivedData/screenshot-test-$label.log"; then
    echo "error: screenshot test was skipped for $label" >&2
    tail -n 80 "$ROOT/.derivedData/screenshot-test-$label.log" >&2
    return 1
  fi
  collect_shots "$label" "$outdir"
  verify_shots "$label" "$outdir"
  echo "==> shutdown $label"
  shutdown_device "$udid"
}

RUNTIME="$(pick_runtime)"
echo "==> runtime $RUNTIME"
shutdown_if_booted "$IPHONE_NAME" "$IPHONE_TYPE"
shutdown_if_booted "$IPAD_NAME" "$IPAD_TYPE"
IPHONE_UDID="$(ensure_device "$IPHONE_NAME" "$IPHONE_TYPE")"
IPAD_UDID="$(ensure_device "$IPAD_NAME" "$IPAD_TYPE")"
echo "==> iPhone $IPHONE_UDID"
echo "==> iPad $IPAD_UDID"

echo "==> make gen"
make gen

echo "==> build for simulator"
mkdir -p .derivedData
if ! xcodebuild build-for-testing \
  -project mdview.xcodeproj \
  -scheme mdview \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/.derivedData" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  >"$ROOT/.derivedData/screenshot-build.log" 2>&1; then
  echo "error: build-for-testing failed" >&2
  tail -n 120 "$ROOT/.derivedData/screenshot-build.log" >&2
  exit 1
fi

XCTESTRUN="$(python3 - <<'PY'
import os, sys
root = ".derivedData/Build/Products"
found = []
for dirpath, _, files in os.walk(root):
    for name in files:
        if name.endswith(".xctestrun"):
            found.append(os.path.join(dirpath, name))
if not found:
    sys.exit("error: build-for-testing produced no xctestrun")
print(sorted(found)[0])
PY
)"
echo "==> xctestrun $XCTESTRUN"

run_device iphone "$IPHONE_UDID" "$IPHONE_OUT"
run_device ipad "$IPAD_UDID" "$IPAD_OUT"
echo "==> screenshots written"
