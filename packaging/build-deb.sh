#!/bin/bash
# Build kos-desktop_1.0.1.deb from the repo.
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
DEB="kos-desktop_1.0.1.deb"
SENDER_RAW="https://raw.githubusercontent.com/KaiDevious/kos-motd-notif-sender/refs/heads/main"
SENDER_API="https://api.github.com/repos/KaiDevious/kos-motd-notif-sender/contents"
SITE="https://kaidevious.github.io/kOS/"

[ -f "$DEB" ] || { echo "need an existing $DEB as the asset template"; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
dpkg-deb -R "$DEB" "$T"               # unpack current package (images, DEBIAN/) as the base

# --- refresh the parts that are maintained in the repo ---
install -D -m755 "$REPO/scripts/kos-setup.sh"      "$T/usr/local/bin/kos-setup"
install -D -m644 "$REPO/branding/kos-ascii.txt"    "$T/usr/share/kos/kos-ascii.txt"

# desktop themes: KDE color schemes + matching wallpapers (installed by kos-setup)
for f in kOSLamplight.colors kOSLiquidGlass.colors wallpaper-warm.png wallpaper-glass.png; do
  [ -f "$REPO/branding/$f" ] && install -D -m644 "$REPO/branding/$f" "$T/usr/share/kos/$f"
done

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
cat > "$T/etc/kos/config" <<EOF
# kOS broadcast config
BASE_URL="$SENDER_RAW"
API_URL="$SENDER_API"
SITE="$SITE"
NAME="kOS"
EOF

# --- build with xz (fall back to gzip); never zstd ---
if command -v xz >/dev/null 2>&1; then Z="xz"; else Z="gzip"; fi
dpkg-deb -Z"$Z" --build "$T" "$DEB"
echo
echo "built $DEB with $Z compression:"
dpkg-deb -I "$DEB" | sed -n '1,4p'
