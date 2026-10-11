#!/bin/bash
# Can a GitHub Action seed the SDK's config? Two mechanisms to check:
#   1. config.seed, which the kconfig tools read on `make defconfig`
#   2. anything gh-action-sdk already exposes
set -u

echo "=== 1. config.seed support in OpenWrt"
python3 - <<'PY'
import json
try:
    d = json.load(open('/tmp/ow.json'))
except Exception as e:
    print('  tree.json unavailable:', e); raise SystemExit
paths = [x['path'] for x in d.get('tree', [])]
seed = [p for p in paths if 'seed' in p.lower()]
print('  paths mentioning "seed":', seed or 'NONE')
PY

echo
echo "=== 2. does the kconfig conf tool read config.seed?"
for f in scripts/config/confdata.c; do
  printf -- '--- %s\n' "$f"
  curl -sSfL --ssl-no-revoke "https://raw.githubusercontent.com/openwrt/openwrt/main/$f" 2>/dev/null \
    | grep -n -i 'config\.seed\|seed' | head -8
done

echo
echo "=== 3. scripts/defconfig: what does it touch?"
curl -sSfL --ssl-no-revoke "https://raw.githubusercontent.com/openwrt/openwrt/main/scripts/defconfig" 2>/dev/null \
  | grep -n -i 'seed\|\.config\|conf ' | head -12

echo
echo "=== 4. how are @-prefixed DEPENDS emitted into the ipk control?"
curl -sSfL --ssl-no-revoke "https://raw.githubusercontent.com/openwrt/openwrt/main/scripts/package-metadata.pl" -o /tmp/pm.pl 2>/dev/null
echo "  file size: $(wc -c < /tmp/pm.pl 2>/dev/null || echo 0) bytes"
grep -n 'depends\|DEPENDS' /tmp/pm.pl | head -20
