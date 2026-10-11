#!/bin/bash
# Final syntax validation sweep for the spotify-soloist project.
cd /mnt/h/make/spotify-soloist-openwrt || exit 1

fail=0
echo "--- POSIX shell (dash -n)"
for f in spotify-soloist/files/usr/bin/* \
         spotify-soloist/files/usr/lib/spotify-soloist/common.sh \
         spotify-soloist/files/etc/init.d/spotify-soloist \
         .dev/*.sh build.sh install.sh; do
    if dash -n "$f" 2>/tmp/e; then
        printf '  ok    %s\n' "$f"
    else
        printf '  FAIL  %s: %s\n' "$f" "$(cat /tmp/e)"
        fail=1
    fi
done

echo
echo "--- Lua (luac5.1 -p)"
for f in luci-app-spotify-soloist/luasrc/controller/*.lua \
         luci-app-spotify-soloist/luasrc/model/cbi/*.lua; do
    if luac5.1 -p "$f" 2>/tmp/e; then
        printf '  ok    %s\n' "$f"
    else
        printf '  FAIL  %s: %s\n' "$f" "$(cat /tmp/e)"
        fail=1
    fi
done

echo
echo "--- JSON (ACL)"
if python3 -c "import json,sys; json.load(open('luci-app-spotify-soloist/root/usr/share/rpcd/acl.d/luci-app-spotify-soloist.json'))" 2>/tmp/e; then
    echo "  ok    rpcd ACL"
else
    echo "  FAIL  rpcd ACL: $(cat /tmp/e)"
    fail=1
fi

echo
echo "--- line endings (must be LF)"
crlf=0
for f in $(find . -type f -not -path './.git/*' \
        \( -name '*.sh' -o -name '*.lua' -o -name '*.htm' -o -name 'Makefile' \
           -o -name '*.json' -o -name 'spotify-soloist' -o -name 'spotify-soloist-*' \)); do
    if grep -qU $'\r' "$f" 2>/dev/null; then
        echo "  FAIL  CRLF in $f"
        crlf=1
    fi
done
if [ "$crlf" -eq 0 ]; then
    echo "  ok    all files use LF"
else
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "ALL CHECKS PASS"
else
    echo "THERE WERE FAILURES"
fi
exit "$fail"
