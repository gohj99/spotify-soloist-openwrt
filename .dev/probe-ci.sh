#!/bin/bash
# Decide how the package should treat musl, and what the SDK build needs.
set -u

echo "=== 1. gcompat: does OpenWrt have a glibc-compat shim?"
for f in /tmp/pk.json /tmp/ow.json; do :; done
curl -sSfL --ssl-no-revoke "https://api.github.com/repos/openwrt/packages/git/trees/master?recursive=1" -o /tmp/pk.json 2>/dev/null
curl -sSfL --ssl-no-revoke "https://api.github.com/repos/openwrt/openwrt/git/trees/main?recursive=1" -o /tmp/ow.json 2>/dev/null
python3 - <<'PY'
import json
for f, label in (('/tmp/pk.json', 'packages feed'), ('/tmp/ow.json', 'openwrt core')):
    try:
        d = json.load(open(f))
    except Exception as e:
        print(f'  {label}: unreadable ({e})'); continue
    paths = [x['path'] for x in d.get('tree', [])]
    hits = [p for p in paths if 'gcompat' in p.lower() or 'libc6-compat' in p.lower()]
    print(f'  {label}: {len(paths)} entries, gcompat={hits or "NONE"}, truncated={d.get("truncated")}')
PY

echo
echo "=== 2. BROKEN: is it a real kconfig symbol?"
for f in include/package.mk include/toplevel.mk config/Config-build.in \
         config/Config-devel.in scripts/package-metadata.pl; do
  n=$(curl -sSfL --ssl-no-revoke "https://raw.githubusercontent.com/openwrt/openwrt/main/$f" 2>/dev/null \
      | grep -ci 'broken')
  printf '  %-32s broken-mentions=%s\n' "$f" "$n"
done

echo
echo "=== 3. do real packages depend on BROKEN?"
for p in lang/rust/utils/tmux net/nginx; do
  printf -- '  --- %s\n' "$p"
  curl -sSfL --ssl-no-revoke "https://raw.githubusercontent.com/openwrt/packages/master/$p/Makefile" 2>/dev/null \
    | grep -n 'BROKEN\|DEPENDS' | head -3
done

echo
echo "=== 4. extraction tools for the SDK tarball"
for t in zstd tar xz python3; do printf '  %-8s ' "$t"; command -v "$t" >/dev/null && echo ok || echo MISSING; done
tar --help 2>&1 | grep -q -- '--zstd' && echo "  tar --zstd: ok" || echo "  tar --zstd: no"

echo
echo "=== 5. gh-action-sdk default branch + latest tag"
curl -sSfL --ssl-no-revoke "https://api.github.com/repos/openwrt/gh-action-sdk" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('  default_branch:', d.get('default_branch'))" 2>/dev/null
