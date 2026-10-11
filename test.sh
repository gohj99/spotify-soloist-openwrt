#!/bin/bash
# Test script for Spotify Soloist on OpenWrt device

set -e

ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
ROUTER_USER="${ROUTER_USER:-root}"

echo "==================================="
echo "Spotify Soloist Test Suite"
echo "==================================="
echo ""
echo "Target: $ROUTER_USER@$ROUTER_IP"
echo ""

# Function to run command on router
run_remote() {
    ssh "$ROUTER_USER@$ROUTER_IP" "$@"
}

# Test 1: Check if packages are installed
echo "Test 1: Package Installation"
echo "-----------------------------------"
if run_remote "opkg list-installed | grep -q spotify-soloist"; then
    echo "✓ spotify-soloist package installed"
else
    echo "✗ spotify-soloist package NOT installed"
    exit 1
fi

if run_remote "opkg list-installed | grep -q luci-app-spotify-soloist"; then
    echo "✓ luci-app-spotify-soloist package installed"
else
    echo "✗ luci-app-spotify-soloist package NOT installed"
    exit 1
fi
echo ""

# Test 2: Check binary existence
echo "Test 2: Binary Files"
echo "-----------------------------------"
if run_remote "[ -x /usr/sbin/soloist ]"; then
    echo "✓ Soloist binary exists and is executable"
    BINARY_EXISTS=1
else
    echo "⚠ Soloist binary not found (will be downloaded on first start)"
    BINARY_EXISTS=0
fi

if run_remote "[ -x /usr/bin/spotify-soloist-updater ]"; then
    echo "✓ Updater script exists"
else
    echo "✗ Updater script NOT found"
    exit 1
fi

if run_remote "[ -x /usr/bin/spotify-soloist-check ]"; then
    echo "✓ Check script exists"
else
    echo "✗ Check script NOT found"
    exit 1
fi
echo ""

# Test 3: Check configuration files
echo "Test 3: Configuration Files"
echo "-----------------------------------"
if run_remote "[ -f /etc/config/spotify-soloist ]"; then
    echo "✓ UCI config file exists"
else
    echo "✗ UCI config file NOT found"
    exit 1
fi

if run_remote "[ -f /etc/init.d/spotify-soloist ]"; then
    echo "✓ Init script exists"
else
    echo "✗ Init script NOT found"
    exit 1
fi
echo ""

# Test 4: Check UCI configuration
echo "Test 4: UCI Configuration"
echo "-----------------------------------"
DEVICE_NAME=$(run_remote "uci get spotify-soloist.main.device_name 2>/dev/null || echo 'not set'")
echo "Device Name: $DEVICE_NAME"

ENABLED=$(run_remote "uci get spotify-soloist.main.enabled 2>/dev/null || echo '0'")
echo "Enabled: $ENABLED"

WS_ENABLED=$(run_remote "uci get spotify-soloist.main.ws_enabled 2>/dev/null || echo '1'")
echo "WebSocket Enabled: $WS_ENABLED"

AUTO_UPDATE=$(run_remote "uci get spotify-soloist.main.auto_update 2>/dev/null || echo '1'")
echo "Auto Update: $AUTO_UPDATE"
echo ""

# Test 5: Check service status
echo "Test 5: Service Status"
echo "-----------------------------------"
SERVICE_ENABLED=$(run_remote "/etc/init.d/spotify-soloist enabled && echo 1 || echo 0")
if [ "$SERVICE_ENABLED" = "1" ]; then
    echo "✓ Service is enabled"
else
    echo "⚠ Service is not enabled"
fi

if run_remote "pidof soloist >/dev/null 2>&1"; then
    echo "✓ Service is running"
    SERVICE_RUNNING=1
else
    echo "⚠ Service is not running"
    SERVICE_RUNNING=0
fi
echo ""

# Test 6: Check binary download if needed
if [ "$BINARY_EXISTS" = "0" ]; then
    echo "Test 6: Binary Download"
    echo "-----------------------------------"
    echo "Attempting to download binary..."
    if run_remote "/usr/bin/spotify-soloist-updater"; then
        echo "✓ Binary downloaded successfully"
    else
        echo "✗ Binary download failed"
        echo "Check logs: ssh $ROUTER_USER@$ROUTER_IP logread | grep soloist"
        exit 1
    fi
    echo ""
fi

# Test 7: Check remaining days (if binary exists)
if [ "$BINARY_EXISTS" = "1" ] || [ "$SERVICE_RUNNING" = "1" ]; then
    echo "Test 7: Expiration Check"
    echo "-----------------------------------"
    DAYS=$(run_remote "/usr/bin/spotify-soloist-check --days 2>/dev/null || echo -1")
    if [ "$DAYS" -gt 0 ]; then
        echo "✓ Remaining days: $DAYS"
        if [ "$DAYS" -le 15 ]; then
            echo "⚠ Warning: Less than 15 days remaining!"
        fi
    else
        echo "⚠ Could not determine remaining days"
    fi
    echo ""
fi

# Test 8: Check cron job
echo "Test 8: Cron Job"
echo "-----------------------------------"
if run_remote "crontab -l 2>/dev/null | grep -q spotify-soloist-check"; then
    echo "✓ Cron job is configured"
    run_remote "crontab -l 2>/dev/null | grep spotify-soloist-check"
else
    echo "⚠ Cron job not found"
fi
echo ""

# Test 9: Check LuCI integration
echo "Test 9: LuCI Integration"
echo "-----------------------------------"
if run_remote "[ -f /usr/lib/lua/luci/controller/spotify-soloist.lua ]"; then
    echo "✓ LuCI controller found"
else
    echo "✗ LuCI controller NOT found"
fi

if run_remote "[ -f /usr/lib/lua/luci/model/cbi/spotify-soloist.lua ]"; then
    echo "✓ LuCI CBI model found"
else
    echo "✗ LuCI CBI model NOT found"
fi
echo ""

# Test 10: Check logs
echo "Test 10: Recent Logs"
echo "-----------------------------------"
echo "Last 10 soloist-related log entries:"
run_remote "logread | grep -i soloist | tail -n 10 || echo 'No logs found'"
echo ""

# Summary
echo "==================================="
echo "Test Summary"
echo "==================================="
echo ""
echo "Core Tests: PASSED"
echo ""
echo "Optional actions:"
echo "  - Enable service: ssh $ROUTER_USER@$ROUTER_IP '/etc/init.d/spotify-soloist enable'"
echo "  - Start service: ssh $ROUTER_USER@$ROUTER_IP '/etc/init.d/spotify-soloist start'"
echo "  - View logs: ssh $ROUTER_USER@$ROUTER_IP 'logread -f | grep soloist'"
echo "  - Access LuCI: http://$ROUTER_IP/cgi-bin/luci/admin/services/spotify-soloist"
echo ""
