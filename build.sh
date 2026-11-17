#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR="${ROOT_DIR}/dist"
OUT_FILE="${OUT_DIR}/voenabler-vn-pixel-qcom-v3.1.0-hxn-labs.zip"

mkdir -p "$OUT_DIR"
rm -f "$OUT_FILE"

if command -v zip >/dev/null 2>&1; then
  (
    cd "$ROOT_DIR"
    zip -r9 "$OUT_FILE" \
      META-INF \
      bin \
      engine \
      system \
      tools \
      webroot \
      action.sh \
      customize.sh \
      module.prop \
      post-fs-data.sh \
      probe-carrier.awk \
      probe-ims.awk \
      probe-radio.awk \
      probe.sh \
      service.sh \
      uninstall.sh \
      -x "*.DS_Store"
  )
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$ROOT_DIR" "$OUT_FILE" << 'PY'
import os, sys, zipfile

root_dir, out_file = sys.argv[1], sys.argv[2]
include_dirs = {"META-INF", "bin", "engine", "system", "tools", "webroot"}
include_files = {
    "action.sh", "customize.sh", "module.prop", "post-fs-data.sh",
    "probe-carrier.awk", "probe-ims.awk", "probe-radio.awk",
    "probe.sh", "service.sh", "uninstall.sh"
}

with zipfile.ZipFile(out_file, "w", zipfile.ZIP_DEFLATED) as zf:
    for item in sorted(include_files):
        p = os.path.join(root_dir, item)
        if os.path.isfile(p):
            zf.write(p, item)
    for d in sorted(include_dirs):
        dp = os.path.join(root_dir, d)
        if not os.path.isdir(dp):
            continue
        for cur, _, files in os.walk(dp):
            for fn in sorted(files):
                if fn == ".DS_Store":
                    continue
                fp = os.path.join(cur, fn)
                zf.write(fp, os.path.relpath(fp, root_dir))
PY
else
  echo "Error: requires 'zip' or 'python3' to build archive." >&2
  exit 1
fi

echo "Built: $OUT_FILE"
