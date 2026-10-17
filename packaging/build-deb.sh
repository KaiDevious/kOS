#!/bin/bash
# Build kos-desktop (version set by VERSION below) from the repo.
#
# IMPORTANT: build with xz (or gzip) compression, NOT zstd. Debian/Kali `apt`
# rejects zstd-compressed .debs with "Unsupported file ... given on commandline"
# (zstd in .deb is an Ubuntu-only extension). `dpkg -i` tolerates zstd but
# `apt install ./file.deb` does not — so we always use xz here.
#
# It refreshes the scripts/branding that live in the repo, then rebuilds. The
# package's images come from the current committed .deb, used as a template.
set -e
cd "$(dirname "$0")"
REPO=".."
VERSION="1.3.1"
# build codename (K-creature series): Kestrel -> Kodiak -> Kraken -> Kinkajou -> Kakapo -> Kudu ...
CODENAME="Kestrel"
DEB="kos-desktop_${VERSION}.deb"
SENDER_RAW="https://raw.githubusercontent.com/KaiDevious/kos-motd-notif-sender/refs/heads/main"
SENDER_API="https://api.github.com/repos/KaiDevious/kos-motd-notif-sender/contents"
SITE="https://kaidevious.github.io/kOS/"

# use the newest existing kos-desktop_*.deb as the asset template (images, DEBIAN/)
TEMPLATE="$(ls -1 kos-desktop_*.deb 2>/dev/null | sort -V | tail -1)"
[ -n "$TEMPLATE" ] || { echo "need an existing kos-desktop_*.deb as the asset template"; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
dpkg-deb -R "$TEMPLATE" "$T"           # unpack current package (images, DEBIAN/) as the base
sed -i "s/^Version:.*/Version: ${VERSION}/" "$T/DEBIAN/control"   # bump version
sed -i 's/sudo kos-setup/sudo kos setup/g' "$T/DEBIAN/postinst" 2>/dev/null || true
# GUI app runtime deps (idempotent)
grep -q 'gir1.2-gtk-4.0' "$T/DEBIAN/control" || \
  sed -i 's/^Depends: \(.*\)/Depends: \1, python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1/' "$T/DEBIAN/control"

# --- refresh the parts that are maintained in the repo ---
install -D -m755 "$REPO/scripts/kos-setup.sh"      "$T/usr/bin/kos-setup"
install -D -m755 "$REPO/scripts/kos"               "$T/usr/bin/kos"
install -D -m644 "$REPO/branding/kos-ascii.txt"    "$T/usr/share/kos/kos-ascii.txt"
printf '%s\n' "$CODENAME" > "$T/usr/share/kos/codename"   # build codename

# startup chime (played on login by kos-setup's autostart entry)
[ -f "$REPO/branding/startup.oga" ] && install -D -m644 "$REPO/branding/startup.oga" "$T/usr/share/kos/startup.oga"

# desktop themes: KDE color schemes + matching wallpapers (installed by kos-setup)
for f in kOSLamplight.colors kOSLiquidGlass.colors wallpaper-warm.png wallpaper-glass.png; do
  [ -f "$REPO/branding/$f" ] && install -D -m644 "$REPO/branding/$f" "$T/usr/share/kos/$f"
done
# GRUB theme folder (theme.txt + selection pixmaps), installed by kos-setup
if [ -d "$REPO/branding/grub-theme" ]; then
  mkdir -p "$T/usr/share/kos/grub-theme"
  cp "$REPO/branding/grub-theme/"* "$T/usr/share/kos/grub-theme/"
fi

# kOS Control Center — native GTK app, shipped with the OS (menu entry + icon)
if [ -f "$REPO/app/control-center/main.py" ]; then
  install -D -m755 "$REPO/app/control-center/main.py" "$T/usr/bin/kos-control-center"
  install -D -m644 "$REPO/app/control-center/io.github.kaidevious.kOS.desktop" "$T/usr/share/applications/io.github.kaidevious.kOS.desktop"
  install -D -m644 "$REPO/app/control-center/logo.png" "$T/usr/share/kos/kos-logo.png"
  install -D -m644 "$REPO/app/control-center/logo.png" "$T/usr/share/icons/hicolor/256x256/apps/io.github.kaidevious.kOS.png"
fi

# distinct icons for the kOS app-menu entries + the Control Center
for ic in kos-website kos-bugs kos-docs kos-github kos-control-center; do
  [ -f "$REPO/branding/app-icons/$ic.png" ] && \
    install -D -m644 "$REPO/branding/app-icons/$ic.png" "$T/usr/share/icons/hicolor/256x256/apps/$ic.png"
done

# kOS Welcome — first-boot OOBE wizard (autostarts once on first login)
if [ -f "$REPO/app/oobe/main.py" ]; then
  install -D -m755 "$REPO/app/oobe/main.py"       "$T/usr/bin/kos-oobe"
  install -D -m644 "$REPO/app/oobe/kos-oobe.desktop" "$T/etc/xdg/autostart/kos-oobe.desktop"
fi

# config-driven notifier: fresh GitHub API (ETag-conditional) + raw fallback + poll handling
cat > "$T/usr/local/bin/kos-notify" <<'EOF'
#!/bin/bash
CONF=/etc/kos/config; [ -r "$CONF" ] && . "$CONF"
: "${BASE_URL:=}"; : "${API_URL:=}"; : "${NAME:=kOS}"; : "${SITE:=https://kaidevious.github.io/kOS/}"
[ -z "$BASE_URL" ] && exit 0
STATE="$HOME/.cache/kos-last-notify"; ETAGF="$HOME/.cache/kos-notify-etag"; mkdir -p "$HOME/.cache"
sleep 15
while true; do
  MSG=""
  if [ -n "$API_URL" ] && MSG=$(curl -fsS --max-time 6 -H "User-Agent: $NAME" -H "Accept: application/vnd.github.raw" \
       --etag-compare "$ETAGF" --etag-save "$ETAGF" "$API_URL/notify.txt" 2>/dev/null); then
    :                                   # empty on a 304 (unchanged) -> skipped below
  else
    MSG=$(curl -fsS --max-time 6 "$BASE_URL/notify.txt?t=$(date +%s)" 2>/dev/null)
  fi
  if [ -n "$MSG" ] && [ "$MSG" != "$(cat "$STATE" 2>/dev/null)" ]; then
    if printf '%s' "$MSG" | grep -qE '/[^/\\]+\\[[:space:]]*$'; then
      Q=$(printf '%s' "$MSG" | sed -E 's:[[:space:]]*/[^/\\]+\\[[:space:]]*$::'); [ -z "$Q" ] && Q="New poll"
      notify-send -a "$NAME" "$NAME poll" "$Q
Vote: $SITE"
    else
      notify-send -a "$NAME" "$NAME" "$MSG"
    fi
    printf '%s' "$MSG" > "$STATE"
  fi
  sleep 15
done
EOF
chmod 755 "$T/usr/local/bin/kos-notify"

# broadcast config (conffile)
# DIAG_URL is the opt-in diagnostics webhook. It is NEVER hardcoded in the repo —
# set it at build time:  KOS_DIAG_URL="https://discord.com/api/webhooks/..." ./build-deb.sh
# (left blank here, so the public source carries no webhook).
cat > "$T/etc/kos/config" <<EOF
# kOS broadcast config
BASE_URL="$SENDER_RAW"
API_URL="$SENDER_API"
SITE="$SITE"
NAME="kOS"
DIAG_URL="${KOS_DIAG_URL:-}"
EOF

# --- build with xz (fall back to gzip); never zstd ---
if command -v xz >/dev/null 2>&1; then Z="xz"; else Z="gzip"; fi
dpkg-deb -Z"$Z" --build "$T" "$DEB"
echo
echo "built $DEB with $Z compression:"
dpkg-deb -I "$DEB" | sed -n '1,4p'
