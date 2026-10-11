module("luci.controller.spotify-soloist", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/spotify-soloist") then
		return
	end

	local page

	page = entry({"admin", "services", "spotify-soloist"},
		cbi("spotify-soloist"),
		_("Spotify Soloist"), 60)
	page.dependent = true
	page.acl_depends = { "luci-app-spotify-soloist" }

	entry({"admin", "services", "spotify-soloist", "status"},
		call("action_status")).leaf = true

	entry({"admin", "services", "spotify-soloist", "update"},
		call("action_update")).leaf = true

	entry({"admin", "services", "spotify-soloist", "check_days"},
		call("action_check_days")).leaf = true
end

function action_status()
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()

	local status = {
		running = false,
		enabled = false,
		binary_exists = false,
		days_remaining = -1,
		version = "unknown",
		device_name = "unknown",
		ws_enabled = false,
		ws_port = 8080
	}

	-- Check if binary exists
	status.binary_exists = nixio.fs.access("/usr/sbin/soloist", "x")

	-- Check if service is running
	status.running = (sys.call("pidof soloist > /dev/null 2>&1") == 0)

	-- Get UCI config
	status.enabled = (uci:get("spotify-soloist", "main", "enabled") == "1")
	status.device_name = uci:get("spotify-soloist", "main", "device_name") or "OpenWrt Spotify"
	status.ws_enabled = (uci:get("spotify-soloist", "main", "ws_enabled") == "1")
	status.ws_port = uci:get("spotify-soloist", "main", "ws_port") or "8080"

	-- Get version if binary exists
	if status.binary_exists then
		local version_cmd = "/usr/sbin/soloist --version 2>&1"
		local version_output = sys.exec(version_cmd)
		if version_output and version_output ~= "" then
			status.version = version_output:match("soloist ([%d%.]+)") or version_output:sub(1, 50)
		end
	end

	-- Get remaining days
	status.days_remaining = get_remaining_days()

	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end

function action_update()
	local sys = require "luci.sys"

	luci.http.prepare_content("application/json")

	local result = sys.call("/usr/bin/spotify-soloist-updater > /tmp/soloist-update.log 2>&1")

	local log = ""
	local log_file = io.open("/tmp/soloist-update.log", "r")
	if log_file then
		log = log_file:read("*all")
		log_file:close()
	end

	luci.http.write_json({
		success = (result == 0),
		message = (result == 0) and "Update completed successfully" or "Update failed",
		log = log
	})
end

function action_check_days()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		days_remaining = get_remaining_days()
	})
end

function get_remaining_days()
	local sys = require "luci.sys"

	-- Try to get remaining days from check script
	local days_output = sys.exec("/usr/bin/spotify-soloist-check --days 2>/dev/null")
	local days = tonumber(days_output)

	if not days or days < 0 then
		-- Fallback: try to parse from logs
		local log_cmd = "logread | grep -i soloist | grep -iE '(expire|remaining|days left)' | tail -n 1"
		local log_output = sys.exec(log_cmd)

		if log_output and log_output ~= "" then
			-- Try to extract number before "days"
			days = tonumber(log_output:match("(%d+)%s+days?"))
		end
	end

	return days or -1
end
