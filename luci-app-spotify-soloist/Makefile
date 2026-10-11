#
# LuCI interface for the Spotify Soloist service.
#
# This package only draws the pages and calls into the shell helpers that the
# spotify-soloist package installs; it owns no logic of its own.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-spotify-soloist
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Spotify Soloist OpenWrt contributors

LUCI_TITLE:=LuCI support for Spotify Soloist
LUCI_DEPENDS:=+spotify-soloist +luci-compat

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-spotify-soloist
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
  PKGARCH:=all
endef

define Package/luci-app-spotify-soloist/description
  Configuration, status, audio routing and build-update controls for the
  Spotify Soloist headless Spotify Connect client.
endef

define Build/Compile
endef

define Package/luci-app-spotify-soloist/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/*.lua $(1)/usr/lib/lua/luci/model/cbi/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/spotify-soloist
	$(INSTALL_DATA) ./luasrc/view/spotify-soloist/*.htm $(1)/usr/lib/lua/luci/view/spotify-soloist/
endef

$(eval $(call BuildPackage,luci-app-spotify-soloist))
