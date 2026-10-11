local m, s, o

m = Map("spotify-soloist", translate("Spotify Soloist"),
	translate("Spotify Soloist is a headless Spotify Connect client. " ..
		"It allows your OpenWrt device to appear as a Spotify Connect speaker."))

-- Service Status Section
s = m:section(TypedSection, "spotify-soloist", translate("Service Status"))
s.anonymous = true
s.addremove = false

o = s:option(DummyValue, "_status", translate("Service Status"))
o.template = "spotify-soloist/status"
o.width = "100%"

-- Basic Settings Section
s = m:section(TypedSection, "spotify-soloist", translate("Basic Settings"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable"))
o.default = "0"
o.rmempty = false

o = s:option(Value, "device_name", translate("Device Name"),
	translate("The name that will appear in Spotify Connect device list"))
o.default = "OpenWrt Spotify"
o.placeholder = "OpenWrt Spotify"

o = s:option(ListBox, "bitrate", translate("Audio Bitrate"),
	translate("Preferred audio quality. Higher quality requires more bandwidth."))
o:value("default", translate("Default (Adaptive)"))
o:value("96", "96 kbps")
o:value("160", "160 kbps")
o:value("320", "320 kbps")
o.default = "default"

o = s:option(Flag, "normalize_volume", translate("Volume Normalization"),
	translate("Enable volume normalization to make all tracks play at similar volume"))
o.default = "0"

o = s:option(Value, "cache_size_limit", translate("Cache Size Limit (MB)"),
	translate("Maximum disk space for audio cache"))
o.datatype = "range(64, 4096)"
o.default = "512"
o.placeholder = "512"

-- WebSocket API Section
s = m:section(TypedSection, "spotify-soloist", translate("WebSocket API"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "ws_enabled", translate("Enable WebSocket API"),
	translate("Enable local WebSocket API for integration with other applications"))
o.default = "1"

o = s:option(Value, "ws_port", translate("WebSocket Port"),
	translate("Port for WebSocket API (bound to 127.0.0.1 only)"))
o.datatype = "port"
o.default = "8080"
o.placeholder = "8080"
o:depends("ws_enabled", "1")

-- Auto Update Section
s = m:section(TypedSection, "spotify-soloist", translate("Auto Update Settings"))
s.anonymous = true
s.addremove = false
s.description = translate("Spotify Soloist binaries expire after 90 days. " ..
	"Configure automatic updates to keep the service running.")

o = s:option(Flag, "auto_update", translate("Enable Auto Update"),
	translate("Automatically download and install updates before expiration"))
o.default = "1"

o = s:option(Value, "update_threshold", translate("Update Threshold (Days)"),
	translate("Trigger update when remaining days fall below this value"))
o.datatype = "range(1, 89)"
o.default = "15"
o.placeholder = "15"
o:depends("auto_update", "1")

o = s:option(Value, "check_update_cron", translate("Update Check Schedule"),
	translate("Cron expression for update checks (default: weekly on Sunday 3 AM)"))
o.default = "0 3 * * 0"
o.placeholder = "0 3 * * 0"
o:depends("auto_update", "1")

-- Advanced Settings Section
s = m:section(TypedSection, "spotify-soloist", translate("Advanced Settings"))
s.anonymous = true
s.addremove = false

o = s:option(ListBox, "log_level", translate("Log Level"),
	translate("Logging verbosity"))
o:value("error", translate("Error"))
o:value("warn", translate("Warning"))
o:value("info", translate("Info"))
o:value("debug", translate("Debug"))
o:value("trace", translate("Trace"))
o.default = "info"

return m
