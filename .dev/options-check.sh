#!/bin/bash
# Cross-check the three places that must agree about options:
#   /etc/config/spotify-soloist   (what exists)
#   the CBI model                 (what the UI edits)
#   README.md / README_EN.md      (what is documented)
# Also confirms the init script reads anything the UI can set.
cd /mnt/h/make/spotify-soloist-openwrt || exit 1

CFG=spotify-soloist/files/etc/config/spotify-soloist
CBI=luci-app-spotify-soloist/luasrc/model/cbi/spotify-soloist.lua
INIT=spotify-soloist/files/etc/init.d/spotify-soloist
STATUS=spotify-soloist/files/usr/bin/spotify-soloist-status
AUX=spotify-soloist/files/usr/bin/spotify-soloist-audio

# Only lines that are genuinely `option <name> '<value>'`
grep -oE "^[[:space:]]*option[[:space:]]+[a-z_]+" "$CFG" |
    awk '{print $NF}' | sort -u > /tmp/opt_cfg.txt

grep -oE '"[a-z_]+"' "$CBI" | tr -d '"' | sort -u > /tmp/opt_cbi.txt
grep -oE "s:option\([A-Za-z]+, *\"[a-z_]+\"" "$CBI" |
    sed 's/.*"\([a-z_]*\)"/\1/' | sort -u > /tmp/opt_cbi_fields.txt

grep -oE '^\| `[a-z_]+`' README.md | tr -d '|` ' | sort -u > /tmp/opt_readme.txt
grep -oE '^\| `[a-z_]+`' README_EN.md | tr -d '|` ' | sort -u > /tmp/opt_readme_en.txt

echo "=== defined in UCI:            $(wc -l < /tmp/opt_cfg.txt)"
echo "=== editable via CBI fields:   $(wc -l < /tmp/opt_cbi_fields.txt)"
echo "=== documented in README.md:   $(wc -l < /tmp/opt_readme.txt)"
echo "=== documented in README_EN:   $(wc -l < /tmp/opt_readme_en.txt)"
echo

echo "=== UCI options with no CBI field (cannot be edited in LuCI)"
comm -23 /tmp/opt_cfg.txt /tmp/opt_cbi_fields.txt | sed 's/^/    /'
echo
echo "=== CBI fields not defined in UCI (would edit nothing)"
comm -13 /tmp/opt_cfg.txt /tmp/opt_cbi_fields.txt | sed 's/^/    /'
echo
echo "=== UCI options missing from README.md"
comm -23 /tmp/opt_cfg.txt /tmp/opt_readme.txt | sed 's/^/    /'
echo
echo "=== UCI options missing from README_EN.md"
comm -23 /tmp/opt_cfg.txt /tmp/opt_readme_en.txt | sed 's/^/    /'
echo
echo "=== UCI options the init script never reads"
for o in $(cat /tmp/opt_cfg.txt); do
    grep -q "main $o " "$INIT" || echo "    $o"
done
echo
echo "=== UCI options nothing outside /etc/config references at all"
for o in $(cat /tmp/opt_cfg.txt); do
    n=$(grep -rlw "$o" spotify-soloist/files luci-app-spotify-soloist 2>/dev/null |
        grep -v 'etc/config/spotify-soloist' | wc -l)
    [ "$n" -eq 0 ] && echo "    $o"
done
