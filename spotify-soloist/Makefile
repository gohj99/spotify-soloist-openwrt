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
	+pulseaudio-daemon +libpulse +alsa-utils
  USERID:=soloist=soloist:audio=29,pulse
endef

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
	# Installed here but harmless until updates are enabled: the check script
	# exits immediately while auto_update is off.
	CRON_LINE="17 4 * * 0 /usr/bin/spotify-soloist-check"
	if ! crontab -l 2>/dev/null | grep -qF "spotify-soloist-check"; then
		(crontab -l 2>/dev/null; echo "$$CRON_LINE") | crontab - 2>/dev/null
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
