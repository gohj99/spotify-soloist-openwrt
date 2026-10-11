#!/bin/bash
# Functional test for the spotify-soloist shell scripts.
# Builds a sandbox that mimics the paths the scripts expect, then exercises them
# against the real Spotify Soloist binary.
set -u

SRC=/mnt/h/make/spotify-soloist-openwrt/spotify-soloist/files
ROOT=/tmp/solft4
rm -rf "$ROOT"
mkdir -p "$ROOT"/usr/sbin "$ROOT"/usr/lib/spotify-soloist "$ROOT"/usr/bin \
         "$ROOT"/etc/spotify-soloist/data "$ROOT"/etc/config \
         "$ROOT"/tmp/spotify-soloist/cache "$ROOT"/var/lock "$ROOT"/lib

# A faithful stand-in for OpenWrt's /lib/functions.sh: the config file is shell
# source whose `config' and `option' keywords are functions.
cat > "$ROOT/lib/functions.sh" <<'FN'
CONFIG_SECTION=""
config_load() {
    [ -f "$SANDBOX_ETC/$1" ] && . "$SANDBOX_ETC/$1"
}
config()  { CONFIG_SECTION="$2"; }
option()  { eval "CFG_${CONFIG_SECTION}_$1=\"\$2\""; }
config_get() {
    local out="$1"
    eval "$out=\"\${CFG_${2}_${3}:-$4}\""
}
config_get_bool() { config_get "$@"; }
FN

cp "$SRC/usr/lib/spotify-soloist/common.sh" "$ROOT/usr/lib/spotify-soloist/"

# Rewrite the absolute paths to live inside the sandbox.
sed -i \
  -e "s|^\[ -f /lib/functions.sh \] && . /lib/functions.sh|. \$SB/lib/functions.sh|" \
  -e "s|^SOLOIST_BIN=.*|SOLOIST_BIN=\"\$SB/usr/sbin/soloist\"|" \
  -e "s|^SOLOIST_CONF_DIR=.*|SOLOIST_CONF_DIR=\"\$SB/etc/spotify-soloist\"|" \
  -e "s|^SOLOIST_SHA256_FILE=.*|SOLOIST_SHA256_FILE=\"\$SB/etc/spotify-soloist/sha256\"|" \
  -e "s|^SOLOIST_DATA_DIR=.*|SOLOIST_DATA_DIR=\"\$SB/etc/spotify-soloist/data\"|" \
  -e "s|^SOLOIST_CACHE_DIR=.*|SOLOIST_CACHE_DIR=\"\$SB/tmp/spotify-soloist/cache\"|" \
  -e "s|^SOLOIST_WORK_DIR=.*|SOLOIST_WORK_DIR=\"\$SB/tmp/spotify-soloist\"|" \
  -e "s|^SOLOIST_LOG=.*|SOLOIST_LOG=\"\$SB/tmp/spotify-soloist/update.log\"|" \
  -e "s|^SOLOIST_META=.*|SOLOIST_META=\"\$SB/tmp/spotify-soloist/build.txt\"|" \
  -e "s|^SOLOIST_LOCK=.*|SOLOIST_LOCK=\"\$SB/var/lock/update.lock\"|" \
  "$ROOT/usr/lib/spotify-soloist/common.sh"

# Define the sandbox up front so the sourced helpers can find things.
printf 'SB=%s\nSANDBOX_ETC=%s\n' "$ROOT" "$ROOT/etc/config" \
  > "$ROOT/usr/lib/spotify-soloist/sandbox.sh"
sed -i "1i . $ROOT/usr/lib/spotify-soloist/sandbox.sh" \
  "$ROOT/usr/lib/spotify-soloist/common.sh"

for s in spotify-soloist-status spotify-soloist-check spotify-soloist-audio; do
    cp "$SRC/usr/bin/$s" "$ROOT/usr/bin/$s"
    chmod +x "$ROOT/usr/bin/$s"
    sed -i -e "s|/usr/lib/spotify-soloist/common.sh|$ROOT/usr/lib/spotify-soloist/common.sh|" \
           -e "s|/usr/sbin/soloist|$ROOT/usr/sbin/soloist|g" \
           -e "s|/etc/spotify-soloist|$ROOT/etc/spotify-soloist|g" \
           "$ROOT/usr/bin/$s"
done

cp /tmp/sol/soloist "$ROOT/usr/sbin/soloist"
chmod 755 "$ROOT/usr/sbin/soloist"
echo "test-key-abcdefghijklmnop" > "$ROOT/etc/spotify-soloist/api-key"

printf "config spotify-soloist 'main'\n\toption enabled '1'\n\toption device_name 'Living Room'\n\toption audio_backend 'pulseaudio'\n\toption alsa_output 'hw:1'\n\toption ws_enabled '1'\n\toption auto_update '1'\n\toption update_threshold '15'\n" \
  > "$ROOT/etc/config/spotify-soloist"

echo "=== status JSON:"
sh "$ROOT/usr/bin/spotify-soloist-status" | python3 -m json.tool
echo
echo "=== check --days (expect 89):"
sh "$ROOT/usr/bin/spotify-soloist-check" --days 2>/dev/null | tail -1
echo
echo "=== audio --resolve hw:0 (no sound server here, expect failure):"
sh "$ROOT/usr/bin/spotify-soloist-audio" --resolve hw:0; echo "    exit $?"
