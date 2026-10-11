#!/bin/bash
# Quick build script for development and testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_PATH="${SDK_PATH:-}"
PACKAGE_ARCH="${PACKAGE_ARCH:-all}"

echo "==================================="
echo "Spotify Soloist OpenWrt Build Script"
echo "==================================="
echo ""

# Check if SDK path is provided
if [ -z "$SDK_PATH" ]; then
    echo "ERROR: SDK_PATH environment variable not set"
    echo ""
    echo "Usage:"
    echo "  SDK_PATH=/path/to/openwrt-sdk ./build.sh"
    echo ""
    echo "Or download SDK first:"
    echo "  wget https://downloads.openwrt.org/releases/23.05.0/targets/<target>/<subtarget>/openwrt-sdk-*.tar.xz"
    echo "  tar xf openwrt-sdk-*.tar.xz"
    echo "  SDK_PATH=./openwrt-sdk-* ./build.sh"
    exit 1
fi

# Verify SDK exists
if [ ! -d "$SDK_PATH" ]; then
    echo "ERROR: SDK directory not found: $SDK_PATH"
    exit 1
fi

echo "SDK Path: $SDK_PATH"
echo "Package Arch: $PACKAGE_ARCH"
echo ""

# Create package links in SDK
echo "Creating package links..."
rm -f "$SDK_PATH/package/spotify-soloist"
rm -f "$SDK_PATH/package/luci-app-spotify-soloist"
ln -sf "$SCRIPT_DIR/spotify-soloist" "$SDK_PATH/package/spotify-soloist"
ln -sf "$SCRIPT_DIR/luci-app-spotify-soloist" "$SDK_PATH/package/luci-app-spotify-soloist"

cd "$SDK_PATH"

# Update feeds
echo ""
echo "Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# Build packages
echo ""
echo "Building spotify-soloist..."
make package/spotify-soloist/clean V=s
make package/spotify-soloist/compile V=s

echo ""
echo "Building luci-app-spotify-soloist..."
make package/luci-app-spotify-soloist/clean V=s
make package/luci-app-spotify-soloist/compile V=s

# Find built packages
echo ""
echo "==================================="
echo "Build completed!"
echo "==================================="
echo ""
echo "Built packages:"
find bin/packages -name "spotify-soloist*.ipk" -o -name "luci-app-spotify-soloist*.ipk" | while read pkg; do
    echo "  - $pkg"
done

echo ""
echo "To install on your router:"
echo "  scp bin/packages/*/base/spotify-soloist*.ipk root@192.168.1.1:/tmp/"
echo "  scp bin/packages/*/luci/luci-app-spotify-soloist*.ipk root@192.168.1.1:/tmp/"
echo "  ssh root@192.168.1.1"
echo "  opkg install /tmp/spotify-soloist*.ipk"
echo "  opkg install /tmp/luci-app-spotify-soloist*.ipk"
echo ""
