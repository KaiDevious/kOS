#!/bin/bash
# Puts the kOS branding where penguins-eggs looks for it, so the ISO's
# boot menu, installer, installer icon, and live desktop all say kOS.
# Run on the build machine before `sudo eggs remaster`:
#   sudo bash scripts/kos-eggs-branding.sh
set -e
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/installer"
DST=/etc/penguins-eggs.d/branding
U="${SUDO_USER:-$USER}"

echo "==> Boot menu (GRUB + ISOLINUX)"
mkdir -p "$DST/livecd"
cp -f "$SRC/livecd/"* "$DST/livecd/"

echo "==> Installer (Calamares)"
mkdir -p "$DST/calamares/branding"
cp -f "$SRC"/*.png "$SRC/show.qml" "$SRC/branding.desc.tmpl" "$DST/calamares/branding/"
rm -f "$DST/calamares/branding/splash.png"

echo "==> Installer launcher + icon"
mkdir -p "$DST/applications" "$DST/artwork"
cp -f "$SRC/install-system.desktop.tmpl" "$DST/applications/"
cp -f "$HERE/branding/menu-icon.png" "$DST/artwork/install-system.png"

echo "==> Desktop look for the live user (copies $U's Plasma settings to /etc/skel)"
eggs tools skel --user "$U" || echo "   (eggs tools skel failed — run it by hand: sudo eggs tools skel --user $U)"

echo
echo "Done. Now build:  sudo eggs kill && sudo eggs remaster"
