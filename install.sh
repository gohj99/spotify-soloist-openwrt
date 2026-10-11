#!/bin/bash
# Installation script for Spotify Soloist on OpenWrt

set -e

ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
ROUTER_USER="${ROUTER_USER:-root}"
PACKAGE_DIR="${PACKAGE_DIR:-./bin/packages}"

echo "==================================="
echo "Spotify Soloist OpenWrt Installer"
echo "==================================="
echo ""
echo "Target: $ROUTER_USER@$ROUTER_IP"
echo ""

# Check if packages exist
if [ ! -d "$PACKAGE_DIR" ]; then
    echo "ERROR: Package directory not found: $PACKAGE_DIR"
    echo ""
    echo "Build packages first:"
    echo "  SDK_PATH=/path/to/sdk ./build.sh"
    exit 1
fi

# Find packages
SPOTIFY_PKG=$(find "$PACKAGE_DIR" -name "spotify-soloist_*.ipk" | head -n 1)
LUCI_PKG=$(find "$PACKAGE_DIR" -name "luci-app-spotify-soloist_*.ipk" | head -n 1)

if [ -z "$SPOTIFY_PKG" ]; then
    echo "ERROR: spotify-soloist package not found"
    exit 1
fi

if [ -z "$LUCI_PKG" ]; then
    echo "ERROR: luci-app-spotify-soloist package not found"
    exit 1
fi

echo "Found packages:"
echo "  - $SPOTIFY_PKG"
echo "  - $LUCI_PKG"
echo ""

# Confirm
read -p "Continue with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Step 1: Copying packages to router..."
scp "$SPOTIFY_PKG" "$ROUTER_USER@$ROUTER_IP:/tmp/" || {
    echo "ERROR: Failed to copy spotify-soloist package"
    exit 1
}

scp "$LUCI_PKG" "$ROUTER_USER@$ROUTER_IP:/tmp/" || {
    echo "ERROR: Failed to copy luci-app-spotify-soloist package"
    exit 1
}

echo "✓ Packages copied successfully"
echo ""

echo "Step 2: Installing packages..."
ssh "$ROUTER_USER@$ROUTER_IP" "opkg install /tmp/spotify-soloist_*.ipk" || {
    echo "ERROR: Failed to install spotify-soloist"
    exit 1
}

ssh "$ROUTER_USER@$ROUTER_IP" "opkg install /tmp/luci-app-spotify-soloist_*.ipk" || {
    echo "ERROR: Failed to install luci-app-spotify-soloist"
    exit 1
}

echo "✓ Packages installed successfully"
echo ""

echo "Step 3: Cleaning up..."
ssh "$ROUTER_USER@$ROUTER_IP" "rm -f /tmp/spotify-soloist_*.ipk /tmp/luci-app-spotify-soloist_*.ipk"
echo "✓ Cleanup complete"
echo ""

echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure via LuCI Web Interface:"
echo "   http://$ROUTER_IP/cgi-bin/luci/admin/services/spotify-soloist"
echo ""
echo "2. Or via command line:"
echo "   ssh $ROUTER_USER@$ROUTER_IP"
echo "   uci set spotify-soloist.main.enabled='1'"
echo "   uci set spotify-soloist.main.device_name='My Speaker'"
echo "   uci commit spotify-soloist"
echo "   /etc/init.d/spotify-soloist enable"
echo "   /etc/init.d/spotify-soloist start"
echo ""
echo "3. Check status:"
echo "   ssh $ROUTER_USER@$ROUTER_IP '/etc/init.d/spotify-soloist status'"
echo ""
echo "4. View logs:"
echo "   ssh $ROUTER_USER@$ROUTER_IP 'logread | grep soloist'"
echo ""
