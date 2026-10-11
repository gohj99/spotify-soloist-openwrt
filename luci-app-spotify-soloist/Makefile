#
# LuCI interface for the Spotify Soloist service.
#
# This package only draws the pages and calls into the shell helpers that the
# spotify-soloist package installs; it owns no logic of its own.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for Spotify Soloist
LUCI_DESCRIPTION:=Configuration, status, audio routing and build-update \
	controls for the Spotify Soloist headless Spotify Connect client.
LUCI_DEPENDS:=+spotify-soloist +luci-compat
LUCI_PKGARCH:=all

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Spotify Soloist OpenWrt contributors

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
