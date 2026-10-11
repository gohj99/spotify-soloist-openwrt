module("luci.controller.spotify-soloist", package.seeall)

local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

local CONF = "spotify-soloist"

local KEY_STAGING_PREFIX = "/tmp/spotify-soloist-key."
local LOG_FILE = "/tmp/spotify-soloist/update.log"

function index()
	if not fs.access("/etc/config/spotify-soloist") then
		return
	end

	local page = entry(
		{"admin", "services", "spotify-soloist"},
		cbi("spotify-soloist"),
		_("Spotify Soloist"), 60)
	page.dependent = true
	page.acl_depends = { "luci-app-spotify-soloist" }

	entry({"admin", "services", "spotify-soloist", "status"},
		call("action_status")).leaf = true

	entry({"admin", "services", "spotify-soloist", "service"},
		post("action_service")).leaf = true

	entry({"admin", "services", "spotify-soloist", "update"},
		post("action_update")).leaf = true

	entry({"admin", "services", "spotify-soloist", "log"},
		call("action_log")).leaf = true

	entry({"admin", "services", "spotify-soloist", "key"},
		post("action_key")).leaf = true
end

-- Run a command and return its stdout, or nil plus the output on failure.
local function run(cmd)
	local out = sys.exec(cmd .. " 2>&1")
	return out
end

local function json(payload)
	http.prepare_content("application/json")
	http.write_json(payload)
end

local function fail(message, code)
	luci.http.status(code or 500, "Error")
	json({ ok = false, error = message })
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function action_status()
	-- spotify-soloist-status already assembles everything in one pass; the
	-- controller just relays it so there is a single place that knows how to
	-- interrogate the daemon.
	local out = run("/usr/bin/spotify-soloist-status")

	if not out or out == "" then
		return fail("status script produced no output")
	end

	local parsed = nil
	if luci.jsonc then
		local ok, res = pcall(luci.jsonc.parse, out)
		if ok then
			parsed = res
		end
	end

	if not parsed then
		return fail("could not parse the status output")
	end

	-- The update log gets appended to a status response so the UI can show the
	-- tail without a second round trip.
	parsed.log = ""
	if fs.access(LOG_FILE) then
		parsed.log = sys.exec("tail -n 40 " .. LOG_FILE .. " 2>/dev/null") or ""
	end

	local updating = fs.access("/var/lock/spotify-soloist-update.lock")
	parsed.updating = updating and true or false

	json(parsed)
end

-- ---------------------------------------------------------------------------
-- Service control
-- ---------------------------------------------------------------------------

function action_service()
	local action = http.formvalue("action")

	if action ~= "start" and action ~= "stop" and
	   action ~= "restart" and action ~= "enable" and
	   action ~= "disable" then
		return fail("unknown action", 400)
	end

	-- Surface the reason a start fails instead of just the exit status.
	local out = run("/etc/init.d/spotify-soloist " .. action)
	local status = sys.call("/etc/init.d/spotify-soloist running >/dev/null 2>&1")

	json({
		ok = (out ~= nil),
		action = action,
		running = (status == 0),
		output = out or ""
	})
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function action_update()
	local force = http.formvalue("force") == "1"

	-- Downloading tens of megabytes does not fit inside an HTTP request, so the
	-- updater is detached and the browser polls /status until it finishes. The
	-- updater arms its own rollback guard in case we are interrupted.
	local cmd = "/usr/bin/spotify-soloist-updater"
	if force then
		cmd = cmd .. " --force"
	end

	fs.mkdirr("/tmp/spotify-soloist")
	sys.call(": > " .. LOG_FILE)
	sys.call(cmd .. " >> " .. LOG_FILE .. " 2>&1 &")

	json({
		ok = true,
		started = true,
		force = force,
		message = "Update started. This page will refresh when it finishes."
	})
end

function action_log()
	local out = ""
	if fs.access(LOG_FILE) then
		out = sys.exec("tail -n 200 " .. LOG_FILE .. " 2>/dev/null") or ""
	end

	http.prepare_content("text/plain; charset=utf-8")
	http.write(out)
end

-- ---------------------------------------------------------------------------
-- API key
-- ---------------------------------------------------------------------------

function action_key()
	local action = http.formvalue("action")

	if action == "delete" then
		local out = run("/usr/bin/spotify-soloist-set-key --delete")
		return json({ ok = true, output = out or "" })
	end

	local key = http.formvalue("api_key") or ""
	key = key:gsub("^%s+", ""):gsub("%s+$", "")

	if key == "" then
		return fail("paste the API key first", 400)
	end

	-- Stage under /tmp with owner-only permissions, then hand the file to the
	-- setter, which validates it and installs it with mode 0600. The key never
	-- travels through a shell argument, where it would show up in ps.
	local path = KEY_STAGING_PREFIX .. tostring(os.time()) .. "." ..
		tostring(math.random(100000, 999999))

	local fh = io.open(path, "w")
	if not fh then
		return fail("could not stage the key in /tmp")
	end
	fh:write(key .. "\n")
	fh:close()
	fs.chmod(path, 384) -- 0600

	local out = run("/usr/bin/spotify-soloist-set-key " .. path)
	fs.unlink(path)

	local present = (sys.call("/usr/bin/spotify-soloist-set-key --show-status 2>/dev/null | grep -q present") == 0)

	json({
		ok = present,
		stored = present,
		output = out or "",
		error = present and nil or "the key was rejected, see the output"
	})
end
