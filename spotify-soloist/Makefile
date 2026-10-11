include $(TOPDIR)/rules.mk

PKG_NAME:=spotify-soloist
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=Proprietary
PKG_MAINTAINER:=Your Name <your@email.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/spotify-soloist
  SECTION:=multimedia
  CATEGORY:=Multimedia
  TITLE:=Spotify Soloist headless client
  URL:=https://developer.spotify.com/documentation/soloist
  DEPENDS:=+alsa-lib +libpulse +curl +ca-bundle +coreutils-nohup
  PKGARCH:=all
endef

define Package/spotify-soloist/description
  Spotify Soloist is a headless Spotify Connect client for OpenWrt.
  This package provides automatic binary download and update management
  to handle Spotify's 90-day expiration policy.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
	# No compilation needed - binary package
endef

define Package/spotify-soloist/install
	$(INSTALL_DIR) $(1)/usr/sbin
	# Binary will be downloaded on first boot by updater script

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/spotify-soloist $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/spotify-soloist $(1)/etc/config/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-updater $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/spotify-soloist-check $(1)/usr/bin/
endef

define Package/spotify-soloist/conffiles
/etc/config/spotify-soloist
endef

define Package/spotify-soloist/postinst
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

# Initial binary download
echo "Downloading Spotify Soloist binary..."
/usr/bin/spotify-soloist-updater

# Setup cron job for update checks
UPDATE_CRON="0 3 * * 0"
if [ -f /etc/config/spotify-soloist ]; then
	UPDATE_CRON=$$(uci -q get spotify-soloist.main.check_update_cron || echo "0 3 * * 0")
fi

# Add cron entry if not exists
if ! crontab -l 2>/dev/null | grep -q "spotify-soloist-check"; then
	(crontab -l 2>/dev/null; echo "$${UPDATE_CRON} /usr/bin/spotify-soloist-check") | crontab -
	echo "Added cron job for automatic updates"
fi

echo ""
echo "Spotify Soloist has been installed successfully!"
echo "Configure and start with:"
echo "  uci set spotify-soloist.main.enabled='1'"
echo "  uci commit spotify-soloist"
echo "  /etc/init.d/spotify-soloist enable"
echo "  /etc/init.d/spotify-soloist start"
echo ""
exit 0
endef

define Package/spotify-soloist/prerm
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

# Stop service
/etc/init.d/spotify-soloist stop
/etc/init.d/spotify-soloist disable

# Remove cron job
crontab -l 2>/dev/null | grep -v "spotify-soloist-check" | crontab - 2>/dev/null || true

exit 0
endef

$(eval $(call BuildPackage,spotify-soloist))
