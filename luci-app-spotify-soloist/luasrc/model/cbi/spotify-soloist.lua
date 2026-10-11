local fs = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local dispatcher = require "luci.dispatcher"

local m, s, o

m = Map("spotify-soloist", translate("Spotify Soloist"),
	translate("Turns this device into a Spotify Connect speaker using Spotify " ..
		"Soloist, the headless build of Spotify's own playback engine. " ..
		"Once running, the device appears in the Spotify app's device picker " ..
		"on the same network."))

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Status"))
s.anonymous = true
s.addremove = false

o = s:option(DummyValue, "_status", "")
o.template = "spotify-soloist/status"
o.width = "100%"

-- ---------------------------------------------------------------------------
-- API key
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Spotify API key"))
s.anonymous = true
s.addremove = false
s.description = translate(
	"Spotify requires a Soloist API key, and it will only issue one to a " ..
	"Premium account. Create it at developer.spotify.com/dashboard/soloist, " ..
	"then paste it here. The key is stored in /etc/spotify-soloist/api-key " ..
	"with owner-only permissions so it never ends up in the configuration " ..
	"backup or in the process list.")

o = s:option(DummyValue, "_key_state", translate("Key"))
o.template = "spotify-soloist/keyfield"
o.width = "100%"

-- ---------------------------------------------------------------------------
-- Service
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Service"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable Spotify Soloist"))
o.rmempty = false
o.default = "0"
o.description = translate(
	"The service does not start until a valid API key is stored above, even " ..
	"when this is enabled.")

o = s:option(Value, "device_name", translate("Device name"),
	translate("The name shown in the Spotify Connect device picker. Leave " ..
		"empty to use the router's hostname."))
o.placeholder = "OpenWrt speaker"
o.rmempty = true

o = s:option(Flag, "require_pair", translate("Pairing mode"),
	translate("Start Soloist with --pair instead of running normally: it " ..
		"authenticates through Spotify Connect, stores the session in the data " ..
		"directory, and exits. Enable it for one start to pair, then turn it " ..
		"back off. Normal operation pairs on first playback without this."))
o.default = "0"
o.rmempty = false

o = s:option(Value, "initial_volume", translate("Initial volume"),
	translate("Volume applied at startup, 0-100. Spotify's build defaults " ..
		"to 40."))
o.datatype = "range(0,100)"
o.placeholder = "40"
o.rmempty = true

-- ---------------------------------------------------------------------------
-- Audio output
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Audio output"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "audio_backend", translate("Sound server"),
	translate("Spotify Soloist speaks to a sound server, never to ALSA " ..
		"directly. Which card, USB DAC or headphone jack it ends up on is " ..
		"decided by that sound server."))
o:value("auto", translate("Detect automatically"))
o:value("pulseaudio", translate("PulseAudio"))
o:value("pipewire", translate("PipeWire"))
o.default = "auto"
o.rmempty = false

-- Which binaries exist decides the useful hint, and it has to be evaluated at
-- render time, so the options are built dynamically.
local pulse_bin = fs.access("/usr/bin/pulseaudio")
local pw_bin = fs.access("/usr/bin/pipewire") or fs.access("/usr/bin/pipewire-pulse")
local alsa_present = fs.access("/dev/snd/controlC0")

local hint
if not pulse_bin and not pw_bin then
	hint = translate("No sound server is installed. Install pulseaudio-daemon " ..
		"together with kmod-sound-core and the kernel module for your sound " ..
		"card, or audio playback will silently go nowhere.")
elseif not alsa_present then
	hint = translate("A sound server is installed but /dev/snd/controlC0 is " ..
		"missing, so no sound hardware was detected. Check that the kernel " ..
		"module for your card (or for USB audio, kmod-usb-audio) is loaded.")
else
	hint = translate("Sound hardware and a sound server are both present.")
end

o = s:option(DummyValue, "_audio_hint", translate("Detected"))
o.rawhtml = true
o.cfgvalue = function()
	return string.format('<span style="color:%s">%s</span>',
		(pulse_bin or pw_bin) and alsa_present and "#0b7a3b" or "#a15c00",
		luci.xml.pcdata(hint))
end

o = s:option(ListValue, "alsa_output", translate("Output device"),
	translate("Which attached sound card the audio should come out of -- the " ..
		"on-board jack, an HDMI port or a USB sound adapter. Spotify Soloist " ..
		"never opens a card itself: the sound server does, and the selection " ..
		"is applied to this service only, so nothing else on the router is " ..
		"disturbed."))
o.rmempty = false
o.default = "auto"
o:value("auto", translate("System default output"))

-- Probe the hardware and the running sound server once, at render time.
-- /proc/asound/cards is authoritative for what is attached; pactl knows the
-- sound server's name for the same hardware.
do
	local cards = {}
	local helper = "/usr/bin/spotify-soloist-audio"
	local out = sys.exec(helper .. " --list 2>/dev/null")

	for line in (out or ""):gmatch("[^\n]+") do
		local kind, key, desc = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		if kind and key then
			if kind == "hw" then
				cards[#cards + 1] = { key = key, desc = desc }
			end
		end
	end

	-- Fall back to reading /proc directly if the helper is unavailable.
	if #cards == 0 then
		local fh = io.open("/proc/asound/cards", "r")
		if fh then
			local last = nil
			for line in fh:lines() do
				local num = line:match("^%s*(%d+)%s*%[")
				if num then
					last = { key = "hw:" .. num, desc = "" }
					cards[#cards + 1] = last
				elseif last then
					local text = line:match("^%s*%d+%s*%[%w+%]%s*:%s*(.+)$") or
						line:match("^%s*(%S.*%S)%s*$")
					if text and not text:match("^%s*$") then
						last.desc = last.desc == "" and text or last.desc
					end
				end
			end
			fh:close()
		end
	end

	for _, card in ipairs(cards) do
		local label = card.desc ~= "" and
			string.format("%s -- %s", card.key, card.desc) or card.key
		o:value(card.key, luci.xml.pcdata(label))
	end

	if #cards == 0 then
		o:value("none", translate("(no sound card detected)"))
	end
end

o = s:option(Value, "pipewire_device", translate("PipeWire node"),
	translate("Only used by the PipeWire backend, where it becomes Soloist's " ..
		"own --pipewire-device flag and takes precedence over the output " ..
		"device above. A node name or numeric id, as listed by 'wpctl status' " ..
		"or 'pw-cli ls Node'. Leave empty to follow the output device instead."))
o.placeholder = "alsa_output.platform-...analog-stereo"
o.rmempty = true
-- Shown for both "pipewire" and "auto": on a PipeWire system "auto" is the
-- default, and hiding the field there would make it impossible to set. LuCI
-- ORs repeated depends() calls together.
o:depends("audio_backend", "pipewire")
o:depends("audio_backend", "auto")

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Storage"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "data_dir", translate("Data directory"),
	translate("Holds the device identity and the paired Spotify session. " ..
		"Keep this on persistent storage: if it is lost, the speaker has to " ..
		"be paired again from the Spotify app."))
o.default = "/etc/spotify-soloist/data"
o.datatype = "directory"
o.rmempty = false

o = s:option(Value, "cache_dir", translate("Cache directory"),
	translate("Playback cache. The default lives on tmpfs, which is the " ..
		"right choice on a router: the cache is rebuildable and flash is " ..
		"scarce."))
o.default = "/tmp/spotify-soloist/cache"
o.datatype = "directory"
o.rmempty = false

o = s:option(Value, "cache_size", translate("Cache size limit (MB)"),
	translate("0 means no limit. Spotify's build rejects any other value " ..
		"below 100."))
o.datatype = "or(0, range(100,102400))"
o.default = "0"
o.rmempty = true

-- ---------------------------------------------------------------------------
-- Remote control API
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Remote control API"))
s.anonymous = true
s.addremove = false
s.description = translate(
	"The WebSocket API lets other software on this device observe and " ..
	"control playback. It has no authentication of any kind, so enabling it " ..
	"on anything but the loopback address would let anyone on the network " ..
	"control the speaker and read what is playing.")

o = s:option(Flag, "ws_enabled", translate("Enable the WebSocket API"))
o.default = "0"
o.rmempty = false

o = s:option(ListValue, "ws_address", translate("Listen address"),
	translate("Keep this on 127.0.0.1 unless you have deliberately put an " ..
		"authenticating proxy in front of it."))
o:value("127.0.0.1", "127.0.0.1 (loopback only)")
o:value("0.0.0.0", translate("0.0.0.0 (all interfaces, not recommended)"))
o.default = "127.0.0.1"
o:depends("ws_enabled", "1")

o = s:option(Value, "ws_port", translate("Port"),
	translate("Use 0 to let the operating system pick a free port; the " ..
		"chosen port is written to ws.port in the data directory."))
o.datatype = "port"
o.default = "9090"
o:depends("ws_enabled", "1")

-- ---------------------------------------------------------------------------
-- Updates
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Build updates"))
s.anonymous = true
s.addremove = false
s.description = translate(
	"Spotify expires every Soloist build 90 days after its build date, and " ..
	"an expired build exits immediately with status 10. The scheduled check " ..
	"downloads a fresh build before that happens.")

o = s:option(Flag, "auto_update", translate("Download new builds automatically"))
o.default = "1"
o.rmempty = false

o = s:option(Value, "update_threshold", translate("Days before expiry"),
	translate("Start updating once this few days remain. A build takes only " ..
		"a few megabytes, but leave enough room for retries over a flaky " ..
		"connection."))
o.datatype = "range(1,89)"
o.default = "15"
o:depends("auto_update", "1")

o = s:option(Flag, "update_notify_only", translate("Notify only"),
	translate("Log a warning instead of downloading. Useful when the WAN " ..
		"link is metered."))
o.default = "0"
o:depends("auto_update", "1")

o = s:option(Value, "check_update_cron", translate("Check schedule"),
	translate("Cron expression. The default runs the check weekly, early on " ..
		"Sunday morning."))
o.default = "17 4 * * 0"
o.placeholder = "17 4 * * 0"
o:depends("auto_update", "1")

-- ---------------------------------------------------------------------------
-- Advanced
-- ---------------------------------------------------------------------------

s = m:section(NamedSection, "main", "spotify-soloist", translate("Advanced"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "verbose", translate("Verbose logging"))
o.default = "0"
o.rmempty = false

o = s:option(Flag, "run_as_root", translate("Run as root"),
	translate("Off by default: the service runs as the unprivileged " ..
		"'soloist' user, which the package adds to the audio and pulse " ..
		"groups. Turn this on only to diagnose a permissions problem."))
o.default = "0"
o.rmempty = false

return m
