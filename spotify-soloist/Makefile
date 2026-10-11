#
# Spotify Soloist for OpenWrt
#
# This package installs a service wrapper, not a compiled program. Spotify
# publishes Soloist only as a proprietary prebuilt binary, and it asks that
# people fetch it from their download page rather than redistribute it, so the
# binary is deliberately NOT part of this package. It is fetched on the router
# by /usr/bin/spotify-soloist-updater, which is also what keeps the 90-day
# build expiry from taking the speaker offline.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=spotify-soloist
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Spotify Soloist OpenWrt contributors

# Architecture independent: the package is scripts plus configuration. The
# actual binary is downloaded at runtime, so one package serves every target.
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/spotify-soloist
  SECTION:=multimedia
  CATEGORY:=Multimedia
  TITLE:=Spotify Soloist headless Spotify Connect client
  URL:=https://developer.spotify.com/documentation/soloist
  # Spotify publishes glibc builds only. On a musl image the download succeeds
  # and then the binary refuses to execute, so the package is marked
  # unavailable there rather than installing something that cannot run.
  # OpenWrt builds musl by default and no released target overrides that, so
  # in practice this means: build a glibc image with TOOLCHAINOPTS, or do not
  # use this package. See docs/limitations.md.
  DEPENDS:=@(!USE_MUSL||BROKEN) \
	+ca-bundle +curl +libgcc1 +libatomic1 +libpthread +librt \
	+pulseaudio-daemon +pulseaudio-tools +libpulse +alsa-utils \
	+kmod-sound-core +kmod-usb-audio +kmod-sound-soc-core
endef

# Why these dependencies:
#
#   ca-bundle, curl        to download the build over TLS
#   libgcc1, libatomic1    the runtimes the binary links against; libpthread
#                          and librt are separate packages on musl
#   pulseaudio-daemon      the sound server; Soloist has no ALSA or JACK path
#   pulseaudio-tools       pactl, used to list and resolve sinks
#   libpulse               the client library the binary dlopens
#   alsa-utils             aplay/alsamixer/speaker-test, for diagnosis
#   kmod-sound-core        the ALSA core; without it there is no /dev/snd
#   kmod-usb-audio         USB DACs and USB-to-3.5mm adapters, which is the
#                          usual way to get audio out of a router
#   kmod-sound-soc-core    on-board codecs on SoC targets
#
# The kmods can be deselected for a smaller image; the init script reports when
# no card is present rather than failing silently.

define Package/spotify-soloist/description
  Runs Spotify Soloist, a headless Spotify Connect client, as a procd service
  on OpenWrt.

  Soloist is the same playback engine Spotify's own apps use, available as a
  Linux binary without any user interface: the device shows up in the Spotify
  app's Connect device list and plays through the local sound server.

  This package provides the service wrapper, the UCI configuration, the
  WebSocket API endpoint handling and an automatic updater, because Spotify
  builds expire 90 days after their build date and the daemon then exits with
  status 10.

  IMPORTANT: Spotify publishes glibc Linux builds only. They cannot run on a
  standard musl OpenWrt image, and this dependency marks the package
  unavailable there rather than letting it install and fail at runtime.
endef

define Package/spotify-soloist/conffiles
/etc/config/spotify-soloist
endef

# The updater writes this file itself on first run. It holds a secret, so it
# must never be preserved through a sysupgrade or readable by anyone else.
define Package/spotify-soloist/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# --- user and groups -------------------------------------------------
	# Create soloist user if missing, and add to audio+pulse groups.
	# audio: PulseAudio auth group (gid 29, Debian convention)
	# pulse: /var/run/pulse is 0750 pulse:pulse, need membership to traverse
	grep -q '^audio:' /etc/group || echo 'audio:x:29:' >> /etc/group
	grep -q '^pulse:' /etc/group || echo 'pulse:x:1001:' >> /etc/group

	id soloist >/dev/null 2>&1 || {
		uid=$$(awk -F: '$$3>=100 && $$3<60000 {if($$3>m) m=$$3} END {print m+1}' /etc/passwd)
		echo "soloist:x:$$uid:$$uid:Spotify Soloist:/var/run/spotify-soloist:/bin/false" >> /etc/passwd
		echo "soloist:x:$$uid:" >> /etc/group
	}

	for g in audio pulse; do
		grep "^$$g:" /etc/group | grep -q soloist || \
			sed -i "s/^\($$g:.*\)$$/\1,soloist/" /etc/group
	done

	mkdir -p /var/run/spotify-soloist
	chown soloist:soloist /var/run/spotify-soloist

	# --- API key ---------------------------------------------------------
	mkdir -p /etc/spotify-soloist
	chmod 0700 /etc/spotify-soloist
	if [ ! -f /etc/spotify-soloist/api-key ]; then
		: > /etc/spotify-soloist/api-key
	fi
	chmod 0600 /etc/spotify-soloist/api-key

	# --- persistent state ------------------------------------------------
	mkdir -p /etc/spotify-soloist/data
	chown soloist:soloist /etc/spotify-soloist/data 2>/dev/null
	chmod 0700 /etc/spotify-soloist/data

	# --- volatile cache --------------------------------------------------
	mkdir -p /tmp/spotify-soloist/cache
	chown -R soloist:soloist /tmp/spotify-soloist 2>/dev/null

	# --- cron ------------------------------------------------------------
	# The schedule is a UCI option, so it is written through the same helper
	# that runs whenever the configuration is applied. Doing it inline here
	# would leave the crontab stale as soon as someone changed the schedule in
	# LuCI, which is what used to happen.
	if [ -x /usr/bin/spotify-soloist-cron ]; then
		/usr/bin/spotify-soloist-cron sync 2>/dev/null
	fi

	# --- bring the daemon in line with the config ------------------------
	# The service is disabled by default, so this only matters on reinstall.
	if [ -x /etc/init.d/spotify-soloist ]; then
		/etc/init.d/spotify-soloist enabled && echo "restart" >/dev/null 2>&1
	fi

	echo ""
	echo "Spotify Soloist installed."
	echo ""
	echo "Next steps:"
	echo "  1. Generate an API key at https://developer.spotify.com/dashboard/soloist"
	echo "  2. Open LuCI: Services -> Spotify Soloist, paste the key and enable it"
	echo "     (or: uci set spotify-soloist.main.enabled=1 && uci commit spotify-soloist)"
	echo "  3. The binary is downloaded on first start; check with:"
	echo "     /etc/init.d/spotify-soloist info"
	echo ""
}
exit 0
endef

define Package/spotify-soloist/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/spotify-soloist stop 2>/dev/null
	/etc/init.d/spotify-soloist disable 2>/dev/null

	crontab -l 2>/dev/null | grep -vF "spotify-soloist-check" | crontab - 2>/dev/null

	rm -f /tmp/spotify-soloist/build.txt
}
exit 0
endef

define Package/spotify-soloist/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Keep /etc/config/spotify-soloist (opkg does that for conffiles) but drop
	# the downloaded binary and cached state, which are both large.
	rm -f /usr/sbin/soloist
	rm -rf /tmp/spotify-soloist
}
exit 0
endef

define Build/Prepare
	true
endef

define Build/Compile
	true
endef

define Package/spotify-soloist/install
	$(INSTALL_DIR) $(1)/usr/sbin
	# /usr/sbin/soloist is created at runtime by the updater.

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-updater $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-check $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-set-key $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-status $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-audio $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-cron $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/spotify-soloist
	$(INSTALL_DATA) ./files/usr/lib/spotify-soloist/common.sh $(1)/usr/lib/spotify-soloist/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/spotify-soloist $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/spotify-soloist $(1)/etc/config/

	$(INSTALL_DIR) $(1)/etc/spotify-soloist
	$(INSTALL_DATA) ./files/etc/spotify-soloist/sha256 $(1)/etc/spotify-soloist/
endef

$(eval $(call BuildPackage,spotify-soloist))
