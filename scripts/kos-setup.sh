#!/bin/bash
# kOS v2 setup — run from the folder that holds this script and the assets:
#   cd ~/kos-assets && sudo bash kos-setup.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# assets live in ../branding when run from the repo, or beside the script in the flat kit
ASSETS="$HERE"; [ -d "$HERE/../branding" ] && ASSETS="$(cd "$HERE/../branding" && pwd)"
# installed via the .deb, kos-setup lives in /usr/local/bin and assets ship in /usr/share/kos
[ ! -f "$ASSETS/kos-ascii.txt" ] && [ -f /usr/share/kos/kos-ascii.txt ] && ASSETS=/usr/share/kos
U="${SUDO_USER:-$USER}"
UH="$(getent passwd "$U" | cut -d: -f6)"
REPO="https://raw.githubusercontent.com/KaiDevious/kos-motd-notif-sender/refs/heads/main"
say(){ echo; echo "==> $*"; }

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo: sudo bash kos-setup.sh"; exit 1; fi

# remove stale /usr/local/bin copies from early installs — they shadow the
# package's /usr/bin versions in PATH (this is why 'kos version' lagged behind)
rm -f /usr/local/bin/kos /usr/local/bin/kos-setup /usr/local/bin/kos-theme 2>/dev/null || true

say "1/8  Naming the OS kOS"
cp --remove-destination /usr/lib/os-release /etc/os-release
sed -i 's/^NAME=.*/NAME="kOS"/; s/^PRETTY_NAME=.*/PRETTY_NAME="kOS"/' /etc/os-release
[ -f /etc/lsb-release ] && sed -i 's/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="kOS"/' /etc/lsb-release

say "2/8  Silencing the PC-speaker beep"
printf 'blacklist pcspkr\nblacklist snd_pcsp\n' > /etc/modprobe.d/nobeep.conf
rmmod pcspkr snd_pcsp 2>/dev/null || true
mkdir -p /etc/zsh
grep -q 'unsetopt BEEP' /etc/zsh/zshrc 2>/dev/null || echo 'unsetopt BEEP' >> /etc/zsh/zshrc
grep -q 'bell-style none' /etc/inputrc 2>/dev/null || echo 'set bell-style none' >> /etc/inputrc
mkdir -p /etc/xdg && printf '[Bell]\nSystemBell=false\nVisibleBell=false\n' > /etc/xdg/kaccessrc

# PipeWire pops/beeps in VMs; PulseAudio doesn't. Switch for every user.
apt-get install -y pulseaudio pavucontrol >/dev/null 2>&1 || true
systemctl --global disable pipewire.socket pipewire.service pipewire-pulse.socket pipewire-pulse.service wireplumber.service >/dev/null 2>&1 || true
systemctl --global enable pulseaudio.socket pulseaudio.service >/dev/null 2>&1 || true

say "3/8  fastfetch with the kOS logo"
apt-get install -y fastfetch >/dev/null 2>&1 || true
mkdir -p /usr/share/kos /etc/xdg/fastfetch
cp "$ASSETS/kos-ascii.txt" /usr/share/kos/kos.txt
cat > /etc/xdg/fastfetch/config.jsonc <<'JSON'
{
  "logo": { "source": "/usr/share/kos/kos.txt", "type": "file", "color": { "1": "38;2;134;200;255", "2": "38;2;74;134;240", "3": "38;2;44;98;207" } },
  "modules": [
    {"type":"command","key":"OS","text":". /etc/os-release && echo $PRETTY_NAME $(uname -m)"},
    "kernel","uptime","packages","shell","de","wm","terminal","cpu","gpu","memory","disk","break","colors"
  ]
}
JSON

say "4/8  Wallpapers + desktop themes (Dark, Light, Lamplight, Liquid Glass)"
mkdir -p /usr/share/wallpapers/kOS/contents/images
cp "$ASSETS/wallpaper-dark.png"  /usr/share/wallpapers/kOS/kos-dark.png
cp "$ASSETS/wallpaper-light.png" /usr/share/wallpapers/kOS/kos-light.png
cp "$ASSETS/wallpaper-dark.png"  /usr/share/wallpapers/kOS/contents/images/3840x2160.png
[ -f "$ASSETS/wallpaper-warm.png" ]  && cp "$ASSETS/wallpaper-warm.png"  /usr/share/wallpapers/kOS/kos-lamplight.png
[ -f "$ASSETS/wallpaper-glass.png" ] && cp "$ASSETS/wallpaper-glass.png" /usr/share/wallpapers/kOS/kos-liquidglass.png

# KDE Plasma color schemes matched to the website themes
mkdir -p /usr/share/color-schemes
for CS in kOSLamplight kOSLiquidGlass; do
  [ -f "$ASSETS/$CS.colors" ] && cp "$ASSETS/$CS.colors" /usr/share/color-schemes/
done

# kos-theme: apply a kOS desktop theme (color scheme + matching wallpaper) for the current user.
#   kos-theme lamplight | liquidglass | dark | light
cat > /usr/bin/kos-theme <<'EOF0'
#!/bin/bash
# Apply a kOS desktop look: color scheme + matching wallpaper, live.
WP=/usr/share/wallpapers/kOS
case "${1:-}" in
  lamplight|warm)      SCHEME=kOSLamplight;   PAPER="$WP/kos-lamplight.png";  BREEZE=BreezeDark ;;
  liquidglass|glass)   SCHEME=kOSLiquidGlass; PAPER="$WP/kos-liquidglass.png";BREEZE=BreezeDark ;;
  dark)                SCHEME=BreezeDark;     PAPER="$WP/kos-dark.png";       BREEZE=BreezeDark ;;
  light)               SCHEME=BreezeLight;    PAPER="$WP/kos-light.png";      BREEZE=BreezeLight ;;
  *) echo "usage: kos-theme {lamplight|liquidglass|dark|light}"; exit 1 ;;
esac
[ -f "$PAPER" ] || PAPER="$WP/kos-dark.png"
if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
  plasma-apply-colorscheme "$SCHEME" >/dev/null 2>&1 || plasma-apply-colorscheme "$BREEZE" >/dev/null 2>&1 || true
fi
command -v plasma-apply-wallpaperimage >/dev/null 2>&1 && plasma-apply-wallpaperimage "$PAPER" >/dev/null 2>&1 || true
echo "kOS theme applied: ${1}"
EOF0
chmod 755 /usr/bin/kos-theme

# umbrella 'kos' command (so 'sudo kos setup', 'kos theme ...' work)
[ -f "$HERE/kos" ] && install -D -m755 "$HERE/kos" /usr/bin/kos

say "5/8  Login screen background (SDDM)"
if [ -d /usr/share/sddm/themes/breeze ]; then
  rm -rf /usr/share/sddm/themes/kos
  cp -r /usr/share/sddm/themes/breeze /usr/share/sddm/themes/kos
  cp "$ASSETS/login-dark.png" /usr/share/sddm/themes/kos/kos-login.png
  printf '[General]\nbackground=/usr/share/sddm/themes/kos/kos-login.png\ntype=image\n' > /usr/share/sddm/themes/kos/theme.conf.user
  mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=kos\n' > /etc/sddm.conf.d/zz-kos.conf
else
  echo "   (breeze SDDM theme not found — skipping; we can set this up manually)"
fi

say "6/8  Broadcast: terminal MOTD + desktop notifications"
apt-get install -y curl libnotify-bin >/dev/null 2>&1 || true   # notify-send
# MOTD for login/SSH shells — read the fresh GitHub API, fall back to raw
cat > /etc/profile.d/kos-motd.sh <<'EOF2'
case $- in *i*)
  __kos_m=$(curl -fsS --max-time 6 -H "User-Agent: kOS" -H "Accept: application/vnd.github.raw" \
    "https://api.github.com/repos/KaiDevious/kos-motd-notif-sender/contents/message.txt" 2>/dev/null) \
    || __kos_m=$(curl -4 -fsS --max-time 6 \
    "https://raw.githubusercontent.com/KaiDevious/kos-motd-notif-sender/refs/heads/main/message.txt?t=$(date +%s)" 2>/dev/null)
  [ -n "$__kos_m" ] && printf '%s\n' "$__kos_m"
  unset __kos_m ;;
esac
EOF2
# also show in Konsole (non-login) via bash.bashrc
grep -q kos-motd /etc/bash.bashrc 2>/dev/null || echo '[ -r /etc/profile.d/kos-motd.sh ] && . /etc/profile.d/kos-motd.sh' >> /etc/bash.bashrc
# and in zsh (kOS's default shell), which doesn't read the bash files
mkdir -p /etc/zsh
grep -q kos-motd /etc/zsh/zshrc 2>/dev/null || echo '[ -r /etc/profile.d/kos-motd.sh ] && . /etc/profile.d/kos-motd.sh' >> /etc/zsh/zshrc
# notifier daemon — fresh via GitHub API (ETag-conditional, so unchanged polls
# are free 304s), raw fallback, and clean handling of /y|n\ poll messages
cat > /usr/local/bin/kos-notify.sh <<'EOF3'
#!/bin/bash
STATE="$HOME/.cache/kos-last-notify"; ETAGF="$HOME/.cache/kos-notify-etag"
mkdir -p "$HOME/.cache"
API="https://api.github.com/repos/KaiDevious/kos-motd-notif-sender/contents/notify.txt"
RAW="https://raw.githubusercontent.com/KaiDevious/kos-motd-notif-sender/refs/heads/main/notify.txt"
SITE="https://kaidevious.github.io/kOS/"
sleep 15
while true; do
  if MSG=$(curl -fsS --max-time 6 -H "User-Agent: kOS" -H "Accept: application/vnd.github.raw" \
           --etag-compare "$ETAGF" --etag-save "$ETAGF" "$API" 2>/dev/null); then
    :                                   # MSG is empty on a 304 (unchanged) -> skipped below
  else
    MSG=$(curl -fsS --max-time 6 "$RAW?t=$(date +%s)" 2>/dev/null)   # fallback to raw
  fi
  if [ -n "$MSG" ] && [ "$MSG" != "$(cat "$STATE" 2>/dev/null)" ]; then
    if printf '%s' "$MSG" | grep -qE '/[^/\\]+\\[[:space:]]*$'; then
      Q=$(printf '%s' "$MSG" | sed -E 's:[[:space:]]*/[^/\\]+\\[[:space:]]*$::')
      [ -z "$Q" ] && Q="New poll"
      notify-send -a kOS "kOS poll" "$Q
Vote: $SITE"
    else
      notify-send -a kOS "kOS" "$MSG"
    fi
    printf '%s' "$MSG" > "$STATE"
  fi
  sleep 15
done
EOF3
chmod +x /usr/local/bin/kos-notify.sh
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/kos-notify.desktop <<EOF4
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/kos-notify.sh
Name=kOS Notify
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF4
# apply live now: stop any running notifier and relaunch the new one in the user's session
pkill -f /usr/local/bin/kos-notify 2>/dev/null || true
KOS_U="${SUDO_USER:-$USER}"; KOS_UID="$(id -u "$KOS_U" 2>/dev/null || true)"
if [ -n "$KOS_UID" ] && [ -S "/run/user/$KOS_UID/bus" ]; then
  rm -f "/home/$KOS_U/.cache/kos-last-notify" "/home/$KOS_U/.cache/kos-notify-etag" 2>/dev/null || true
  setsid sudo -u "$KOS_U" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$KOS_UID/bus" \
    /usr/local/bin/kos-notify.sh >/dev/null 2>&1 < /dev/null &
  disown 2>/dev/null || true
  echo "   (notifier restarted for $KOS_U)"
else
  echo "   (notifier will start at next login)"
fi

say "7/8  Colored zsh for new users + you"
apt-get install -y zsh zsh-syntax-highlighting zsh-autosuggestions >/dev/null 2>&1 || true
cat > /etc/skel/.zshrc <<'ZRC'
HISTFILE=~/.zsh_history; HISTSIZE=10000; SAVEHIST=10000; setopt share_history
unsetopt BEEP   # no beeps on tab-complete/errors
autoload -Uz compinit && compinit
PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f$ '
[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZRC
cp /etc/skel/.zshrc "$UH/.zshrc" 2>/dev/null && chown "$U:$U" "$UH/.zshrc"
chsh -s "$(which zsh)" "$U" 2>/dev/null || true

say "8/8  App-menu icon + icon theme"
cp "$ASSETS/logo-dark.png" /usr/share/icons/hicolor/256x256/apps/kos.png 2>/dev/null || true
cp "$ASSETS/menu-icon.png" /usr/share/icons/hicolor/256x256/apps/kos-menu.png 2>/dev/null || true
apt-get install -y papirus-icon-theme >/dev/null 2>&1 || true
grep -q 'Theme=Papirus-Dark' /etc/xdg/kdeglobals 2>/dev/null || printf '\n[Icons]\nTheme=Papirus-Dark\n' >> /etc/xdg/kdeglobals

# NOTE: the launcher icon + favorites are applied at the END of setup, with
# Plasma stopped, so the live session can't overwrite them (see "Apply the
# kOS desktop layout").

say "App menu: hide Kali web links, add kOS ones"
# Hide ONLY the "Kali & OffSec Links" web shortcuts (Bugs, Docs, Forums,
# NetHunter, ...). Leave every actual security tool alone.
# First undo any over-broad NoDisplay we inserted before (right after the
# header), so tools wrongly hidden by earlier versions come back.
for f in /usr/share/applications/kali-*.desktop; do
  [ -f "$f" ] || continue
  sed -i '/^\[Desktop Entry\]/{n;/^NoDisplay=true$/d}' "$f"
  if grep -q 'kali-kali-offsec-links' "$f"; then
    sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
  fi
done
# add kOS app-menu entries (mirror the browser's kOS Links)
koslink(){  # name  url  filename  icon
  cat > "/usr/share/applications/$3" <<EOF2
[Desktop Entry]
Type=Application
Name=$1
Exec=xdg-open $2
Icon=$4
Terminal=false
Categories=Network;
EOF2
}
koslink "kOS Website" "https://kaidevious.github.io/kOS/"        kos-website.desktop kos-website
koslink "kOS Bugs"    "https://github.com/KaiDevious/kOS/issues" kos-bugs.desktop    kos-bugs
koslink "kOS Docs"    "https://github.com/KaiDevious/kOS#readme" kos-docs.desktop    kos-docs
koslink "kOS GitHub"  "https://github.com/KaiDevious/kOS"        kos-github.desktop  kos-github
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

say "GRUB boot menu branding"
cp /etc/default/grub /etc/default/grub.kosbak 2>/dev/null || true
cp "$ASSETS/splash.png" /usr/share/kos/grub-bg.png 2>/dev/null || true
sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="kOS"|' /etc/default/grub
grep -q '^GRUB_DISTRIBUTOR' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="kOS"' >> /etc/default/grub
grep -q '^GRUB_BACKGROUND' /etc/default/grub \
  && sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/usr/share/kos/grub-bg.png"|' /etc/default/grub \
  || echo 'GRUB_BACKGROUND="/usr/share/kos/grub-bg.png"' >> /etc/default/grub
grep -q '^GRUB_TIMEOUT_STYLE' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
# boot on its own after 3s, even after a crash/hard reset (recordfail)
sed -i '/^#\?GRUB_TIMEOUT=/d; /^GRUB_RECORDFAIL_TIMEOUT=/d' /etc/default/grub
printf 'GRUB_TIMEOUT=3\nGRUB_RECORDFAIL_TIMEOUT=3\n' >> /etc/default/grub
grep -q 'splash' /etc/default/grub || sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
# GRUB: keep Kali's stock font + selection highlight (reliable — a full custom
# gfxmenu theme made some VM graphics drivers triple-fault when Enter was
# pressed). We only swap in the kOS background and the "kOS" title text.
# Tear down any custom kOS theme/font from earlier versions first.
rm -rf /boot/grub/themes/kos
rm -f /etc/default/grub.d/zz-kos-theme.cfg
sed -i '/^GRUB_FONT=/d; /^GRUB_THEME=/d' /etc/default/grub 2>/dev/null || true
if [ -f /usr/share/kos/grub-bg.png ]; then
  for TD in /boot/grub/themes/kali /usr/share/grub/themes/kali; do
    [ -d "$TD" ] || continue
    IMG=$(grep -oP 'desktop-image:\s*"?\K[^"]+' "$TD/theme.txt" 2>/dev/null | head -1)
    [ -n "$IMG" ] || IMG=background.png
    cp /usr/share/kos/grub-bg.png "$TD/$IMG" 2>/dev/null || true
  done
fi
update-grub >/dev/null 2>&1 || true

say "Plymouth boot splash"
apt-get install -y plymouth plymouth-label >/dev/null 2>&1 || true
mkdir -p /usr/share/plymouth/themes/kos
cp "$ASSETS/logo-dark.png" /usr/share/plymouth/themes/kos/logo.png 2>/dev/null || true
cat > /usr/share/plymouth/themes/kos/kos.plymouth <<'PLY'
[Plymouth Theme]
Name=kOS
Description=kOS boot splash
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/kos
ScriptFile=/usr/share/plymouth/themes/kos/kos.script
PLY
cat > /usr/share/plymouth/themes/kos/kos.script <<'PLY'
Window.SetBackgroundTopColor(0.031,0.043,0.063);
Window.SetBackgroundBottomColor(0.016,0.024,0.051);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
tick = 0;
fun refresh(){
  tick++;
  logo.sprite.SetX(Window.GetWidth()/2 - logo.image.GetWidth()/2);
  logo.sprite.SetY(Window.GetHeight()/2 - logo.image.GetHeight()/2);
  logo.sprite.SetOpacity(0.8 + 0.2 * Math.Sin(tick/25));
}
Plymouth.SetRefreshFunction(refresh);
PLY
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/kos/kos.plymouth 200 >/dev/null 2>&1 || true
update-alternatives --set default.plymouth /usr/share/plymouth/themes/kos/kos.plymouth >/dev/null 2>&1 || true
update-initramfs -u >/dev/null 2>&1 || true

say "KDE Plasma splash screen"
# a kOS splash: logo + progress bar, shown after login before the desktop paints
SP=/usr/share/plasma/look-and-feel/com.kos.splash
mkdir -p "$SP/contents/splash/images"
cp "$ASSETS/logo-dark.png" "$SP/contents/splash/images/logo.png" 2>/dev/null || true
cat > "$SP/metadata.json" <<'JSON'
{
    "KPlugin": {
        "Id": "com.kos.splash",
        "Name": "kOS",
        "Authors": [{ "Name": "Kai" }],
        "Category": "Plasma Look and Feel",
        "License": "GPL-3.0"
    },
    "X-Plasma-APIVersion": "2"
}
JSON
cat > "$SP/contents/splash/Splash.qml" <<'QML'
import QtQuick 2.5

Rectangle {
    id: root
    color: "#070b0f"
    property int stage

    Image {
        id: logo
        anchors.centerIn: parent
        source: "images/logo.png"
        sourceSize.height: 180
        fillMode: Image.PreserveAspectFit
        opacity: 0
        NumberAnimation on opacity { from: 0; to: 1; duration: 700; running: true }
    }
    Text {
        anchors { top: logo.bottom; topMargin: 20; horizontalCenter: parent.horizontalCenter }
        text: "kOS"
        color: "#86C8FF"
        font.pixelSize: 30
        font.letterSpacing: 3
    }
    Rectangle {
        anchors { bottom: parent.bottom; bottomMargin: 90; horizontalCenter: parent.horizontalCenter }
        width: 220; height: 3; radius: 3; color: "#161c26"
        Rectangle {
            height: parent.height; radius: 3; color: "#4a86f0"
            width: parent.width * Math.min(root.stage / 6, 1)
            Behavior on width { NumberAnimation { duration: 250 } }
        }
    }
}
QML
# select the kOS splash system-wide and for the current user
for F in /etc/xdg/ksplashrc "$UH/.config/ksplashrc"; do
  mkdir -p "$(dirname "$F")"
  printf '[KSplash]\nTheme=com.kos.splash\nEngine=KSplashQML\n' > "$F"
done
chown "$U":"$(id -gn "$U" 2>/dev/null || echo "$U")" "$UH/.config/ksplashrc" 2>/dev/null || true

say "Disable the stock KDE welcome tour (kOS has its own)"
# kOS ships its own Welcome wizard (kos-oobe); suppress Plasma's so they don't collide
mkdir -p "$UH/.config/autostart"
for W in /etc/xdg/autostart/*welcome*.desktop; do
  [ -f "$W" ] || continue
  printf '[Desktop Entry]\nHidden=true\n' > "$UH/.config/autostart/$(basename "$W")"
done
chown -R "$U":"$(id -gn "$U" 2>/dev/null || echo "$U")" "$UH/.config/autostart" 2>/dev/null || true

GRP="$(id -gn "$U" 2>/dev/null || echo "$U")"

say "Login avatar (kOS logo, not the Kali dragon)"
AV=/usr/share/kos/kos-logo.png
if [ -f "$AV" ]; then
  cp "$AV" "$UH/.face.icon" 2>/dev/null && chown "$U":"$GRP" "$UH/.face.icon"
  cp "$AV" "$UH/.face"      2>/dev/null && chown "$U":"$GRP" "$UH/.face"
  mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users
  cp "$AV" "/var/lib/AccountsService/icons/$U"
  AU="/var/lib/AccountsService/users/$U"
  if [ -f "$AU" ] && grep -q '^Icon=' "$AU"; then
    sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/$U|" "$AU"
  elif [ -f "$AU" ]; then
    printf '\n[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$U" >> "$AU"
  else
    printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\nSystemAccount=false\n' "$U" > "$AU"
  fi
fi

say "Konsole: kOS terminal colors"
mkdir -p /usr/share/konsole
cat > /usr/share/konsole/kOS.colorscheme <<'CS'
[Background]
Color=14,20,32
[BackgroundFaint]
Color=14,20,32
[BackgroundIntense]
Color=20,28,44
[Foreground]
Color=212,222,236
[ForegroundFaint]
Color=150,165,188
[ForegroundIntense]
Color=240,245,252
[Color0]
Color=30,36,48
[Color0Intense]
Color=70,80,96
[Color1]
Color=231,76,60
[Color1Intense]
Color=255,110,96
[Color2]
Color=46,204,113
[Color2Intense]
Color=94,235,150
[Color3]
Color=217,154,78
[Color3Intense]
Color=243,201,136
[Color4]
Color=74,134,240
[Color4Intense]
Color=134,200,255
[Color5]
Color=155,89,182
[Color5Intense]
Color=190,130,220
[Color6]
Color=86,200,220
[Color6Intense]
Color=140,225,240
[Color7]
Color=212,222,236
[Color7Intense]
Color=245,250,255
[General]
Blur=false
ColorRandomization=false
Description=kOS
Opacity=1
Wallpaper=
CS
cat > /usr/share/konsole/kOS.profile <<'PF'
[Appearance]
ColorScheme=kOS
[General]
Name=kOS
Parent=FALLBACK/
PF
mkdir -p "$UH/.config"
KC="$UH/.config/konsolerc"
if [ -f "$KC" ] && grep -q '^\[Desktop Entry\]' "$KC"; then
  grep -q '^DefaultProfile=' "$KC" \
    && sed -i 's|^DefaultProfile=.*|DefaultProfile=kOS.profile|' "$KC" \
    || sed -i '/^\[Desktop Entry\]/a DefaultProfile=kOS.profile' "$KC"
else
  printf '[Desktop Entry]\nDefaultProfile=kOS.profile\n' >> "$KC"
fi
chown "$U":"$GRP" "$KC" 2>/dev/null || true

say "kOS global theme (selectable in System Settings)"
LNF=/usr/share/plasma/look-and-feel/com.kos.desktop
mkdir -p "$LNF/contents"
cat > "$LNF/metadata.json" <<'JSON'
{
    "KPlugin": {
        "Id": "com.kos.desktop",
        "Name": "kOS",
        "Category": "Plasma Look and Feel",
        "License": "GPL-3.0"
    },
    "X-Plasma-APIVersion": "2"
}
JSON
cat > "$LNF/contents/defaults" <<'DEF'
[kdeglobals][General]
ColorScheme=kOSLamplight

[kdeglobals][KDE]
widgetStyle=Breeze

[ksplashrc][KSplash]
Theme=com.kos.splash
Engine=KSplashQML

[Wallpaper]
Image=/usr/share/wallpapers/kOS/
DEF
[ -f /usr/share/wallpapers/kOS/kos-lamplight.png ] && \
  cp /usr/share/wallpapers/kOS/kos-lamplight.png "$LNF/contents/preview.png" 2>/dev/null || true

say "Flatpak + Flathub (Discover software store)"
apt-get install -y flatpak plasma-discover-backend-flatpak >/dev/null 2>&1 || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

say "About-this-system branding"
grep -q '^LOGO=' /etc/os-release \
  && sed -i 's|^LOGO=.*|LOGO=io.github.kaidevious.kOS|' /etc/os-release \
  || echo 'LOGO=io.github.kaidevious.kOS' >> /etc/os-release
grep -q '^HOME_URL=' /etc/os-release || echo 'HOME_URL="https://kaidevious.github.io/kOS/"' >> /etc/os-release
grep -q '^SUPPORT_URL=' /etc/os-release || echo 'SUPPORT_URL="https://github.com/KaiDevious/kOS/issues"' >> /etc/os-release

say "Extras: day/night theme, update notifier, tips, chime, aliases"
apt-get install -y cmatrix libnotify-bin >/dev/null 2>&1 || true

# --- helper scripts ---
cat > /usr/bin/kos-daynight <<'EOF'
#!/bin/bash
# warm wallpaper by day, dark by night
h=$(date +%H)
if [ "$h" -ge 7 ] && [ "$h" -lt 19 ]; then wp=kos-lamplight.png; else wp=kos-dark.png; fi
command -v plasma-apply-wallpaperimage >/dev/null 2>&1 && \
  plasma-apply-wallpaperimage "/usr/share/wallpapers/kOS/$wp" >/dev/null 2>&1 || true
EOF
chmod 755 /usr/bin/kos-daynight

cat > /usr/bin/kos-updatecheck <<'EOF'
#!/bin/bash
# notify if a newer kOS is in the repo
inst=$(dpkg-query -W -f='${Version}' kos-desktop 2>/dev/null) || exit 0
repo=$(curl -fsS --max-time 8 "https://kaidevious.github.io/kOS/apt/Packages?t=$(date +%s)" 2>/dev/null \
        | awk '/^Package: kos-desktop/{f=1} f&&/^Version:/{print $2; exit}')
[ -n "$repo" ] || exit 0
if dpkg --compare-versions "$repo" gt "$inst"; then
  command -v notify-send >/dev/null 2>&1 && \
    notify-send -a kOS -i io.github.kaidevious.kOS "kOS update available" \
      "Version $repo is out (you have $inst). Update with:  kos update"
fi
EOF
chmod 755 /usr/bin/kos-updatecheck

cat > /usr/bin/kos-tip <<'EOF'
#!/bin/bash
TIPS=(
  "Switch your whole look live:  kos next"
  "Roll a random accent color:  kos accent random"
  "Keep kOS fresh:  kos update"
  "Re-run the welcome wizard anytime:  kos welcome"
  "Warm by day, dark by night:  kos auto on"
  "Set just the wallpaper:  kos wallpaper liquidglass"
  "Need the weather?  kos weather"
  "Feeling it?  kos party"
  "Open the control panel:  kos center"
  "Every kOS command:  kos help"
)
t="${TIPS[$RANDOM % ${#TIPS[@]}]}"
if [ "$1" = "--notify" ] && command -v notify-send >/dev/null 2>&1; then
  notify-send -a kOS -i io.github.kaidevious.kOS "kOS tip" "$t"
else
  printf '\033[1;34m kOS tip:\033[0m %s\n' "$t"
fi
EOF
chmod 755 /usr/bin/kos-tip

# --- systemd user units ---
mkdir -p /etc/systemd/user
cat > /etc/systemd/user/kos-daynight.service <<'EOF'
[Unit]
Description=kOS day/night wallpaper
[Service]
Type=oneshot
ExecStart=/usr/bin/kos-daynight
EOF
cat > /etc/systemd/user/kos-daynight.timer <<'EOF'
[Unit]
Description=kOS day/night wallpaper timer
[Timer]
OnStartupSec=30
OnCalendar=*-*-* 07,19:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
cat > /etc/systemd/user/kos-updatecheck.service <<'EOF'
[Unit]
Description=kOS update check
[Service]
Type=oneshot
ExecStart=/usr/bin/kos-updatecheck
EOF
cat > /etc/systemd/user/kos-updatecheck.timer <<'EOF'
[Unit]
Description=kOS update check timer
[Timer]
OnStartupSec=2min
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF
# update notifier on by default (non-intrusive); day/night is opt-in via 'kos auto on'
systemctl --global enable kos-updatecheck.timer >/dev/null 2>&1 || true

# --- startup chime + tip-of-the-day on login (KDE autostart) ---
cat > /etc/xdg/autostart/kos-chime.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=kOS startup chime
Exec=sh -c 'sleep 4; paplay /usr/share/kos/startup.oga 2>/dev/null || canberra-gtk-play -f /usr/share/kos/startup.oga 2>/dev/null || true'
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
NoDisplay=true
EOF
cat > /etc/xdg/autostart/kos-tip.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=kOS tip of the day
Exec=sh -c 'sleep 25; kos-tip --notify'
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
NoDisplay=true
EOF

# --- zsh quality-of-life aliases ---
if ! grep -q '# kOS aliases' /etc/zsh/zshrc 2>/dev/null; then
  cat >> /etc/zsh/zshrc <<'EOF'

# kOS aliases
alias update='kos update'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias please='sudo'
alias kfetch='fastfetch'
EOF
fi

say "Apps: Windows (Wine) + Apple file support"
dpkg --add-architecture i386 >/dev/null 2>&1 || true
apt-get update >/dev/null 2>&1 || true
apt-get install -y wine wine64 >/dev/null 2>&1 || true
apt-get install -y wine32:i386 >/dev/null 2>&1 || true
if ! command -v winetricks >/dev/null 2>&1; then
  apt-get install -y cabextract >/dev/null 2>&1 || true
  wget -qO /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && chmod +x /usr/local/bin/winetricks
fi
apt-get install -y libimobiledevice-utils usbmuxd ifuse kio-extras \
  libheif1 libheif-plugin-libde265 heif-thumbnailer \
  ffmpeg gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly 7zip hfsprogs >/dev/null 2>&1 || true
apt-get install -y kimageformat-plugins >/dev/null 2>&1 || apt-get install -y kimageformatplugins >/dev/null 2>&1 || true

say "Firefox: drop the Kali bookmarks, add kOS"
# Enterprise policy: no default (Kali) bookmarks for new profiles + kOS bookmarks.
read -r -d '' KOS_FFPOLICY <<'JSON' || true
{
  "policies": {
    "NoDefaultBookmarks": true,
    "Bookmarks": [
      { "Title": "kOS",          "URL": "https://kaidevious.github.io/kOS/",                 "Placement": "toolbar", "Folder": "kOS Links" },
      { "Title": "kOS GitHub",   "URL": "https://github.com/KaiDevious/kOS",                 "Placement": "toolbar", "Folder": "kOS Links" },
      { "Title": "kOS Docs",     "URL": "https://github.com/KaiDevious/kOS#readme",          "Placement": "toolbar", "Folder": "kOS Links" },
      { "Title": "kOS Bugs",     "URL": "https://github.com/KaiDevious/kOS/issues",          "Placement": "toolbar", "Folder": "kOS Links" },
      { "Title": "kOS Notifier", "URL": "https://github.com/KaiDevious/kos-motd-notif-sender","Placement": "toolbar", "Folder": "kOS Links" },
      { "Title": "My GitHub",    "URL": "https://github.com/KaiDevious",                     "Placement": "toolbar", "Folder": "kOS Links" }
    ]
  }
}
JSON
# write to every place Firefox/Firefox-ESR reads managed policies
for d in /usr/lib/firefox-esr/distribution /usr/lib/firefox/distribution \
         /etc/firefox-esr/policies /etc/firefox/policies; do
  mkdir -p "$d" && printf '%s\n' "$KOS_FFPOLICY" > "$d/policies.json"
done
# best-effort: strip already-created Kali bookmarks from this user's profile(s).
# Catches the "Kali & OffSec Links" folder, everything inside it (NetHunter,
# VulnHub, Exploit Database, OffSec Training...), and any stray Kali/OffSec items.
if command -v sqlite3 >/dev/null 2>&1; then
  for DB in "$UH"/.mozilla/firefox/*/places.sqlite; do
    [ -f "$DB" ] || continue
    sqlite3 "$DB" "
      DELETE FROM moz_bookmarks WHERE parent IN
        (SELECT id FROM moz_bookmarks WHERE type=2
         AND (title LIKE '%Kali%' OR title LIKE '%OffSec%'));
      DELETE FROM moz_bookmarks WHERE title LIKE '%Kali%' OR title LIKE '%OffSec%'
        OR title IN ('Exploit Database','NetHunter','VulnHub');
    " 2>/dev/null || true
  done
fi

say "Apply the kOS desktop layout (launcher icon + favorites)"
KOS_UID="$(id -u "$U" 2>/dev/null || echo 0)"
RT="/run/user/$KOS_UID"
APPLETS="$UH/.config/plasma-org.kde.plasma.desktop-appletsrc"
KW="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
asuser(){ sudo -u "$U" env XDG_RUNTIME_DIR="$RT" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$RT/bus" "$@"; }

# ordered favorites list — config provides the ORDER, the activity DB provides
# membership. Keep the two in sync.
FAVS="io.github.kaidevious.kOS.desktop,kos-website.desktop,kos-bugs.desktop,kos-docs.desktop,kos-github.desktop,org.kde.dolphin.desktop,preferred://browser,org.kde.konsole.desktop,systemsettings.desktop"

if [ -f "$APPLETS" ] && [ -n "$KW" ]; then
  awk '/^\[/{hdr=$0} /^plugin=org\.kde\.plasma\.(kickoff|kicker|kickerdash)/{print hdr}' "$APPLETS" | while read -r grp; do
    [ -n "$grp" ] || continue
    gargs=""; for g in $(printf '%s' "$grp" | sed 's/^\[//; s/\]$//; s/\]\[/ /g'); do gargs="$gargs --group $g"; done
    "$KW" --file "$APPLETS" $gargs --group Configuration --group General --key icon /usr/share/icons/hicolor/256x256/apps/kos-menu.png 2>/dev/null || true
    "$KW" --file "$APPLETS" $gargs --group Configuration --group General --key favorites "$FAVS" 2>/dev/null || true
    "$KW" --file "$APPLETS" $gargs --group Configuration --group General --key favoritesPortedToKAstats true 2>/dev/null || true
  done
  chown "$U":"$(id -gn "$U" 2>/dev/null || echo "$U")" "$APPLETS" 2>/dev/null || true
fi

# Favorites actually live in the KActivities store (ResourceLink table), NOT in
# appletsrc. Write them there directly: drop the Kali favorites, add the kOS set.
# Stop kactivitymanagerd first (SIGKILL, no flush) so it can't overwrite us.
apt-get install -y sqlite3 >/dev/null 2>&1 || true
KADB="$UH/.local/share/kactivitymanagerd/resources/database"
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$KADB" ]; then
  pkill -9 -u "$U" -x kactivitymanagerd 2>/dev/null || true; sleep 1
  AG='org.kde.plasma.favorites.applications'
  sqlite3 "$KADB" "DELETE FROM ResourceLink WHERE initiatingAgent='$AG';" 2>/dev/null || true
  for r in \
    applications:io.github.kaidevious.kOS.desktop \
    applications:kos-website.desktop \
    applications:kos-bugs.desktop \
    applications:kos-docs.desktop \
    applications:kos-github.desktop \
    applications:org.kde.dolphin.desktop \
    preferred://browser \
    applications:org.kde.konsole.desktop \
    applications:systemsettings.desktop ; do
    sqlite3 "$KADB" "INSERT OR IGNORE INTO ResourceLink (usedActivity,initiatingAgent,targettedResource) VALUES (':global','$AG','$r');" 2>/dev/null || true
  done
  chown "$U":"$(id -gn "$U" 2>/dev/null || echo "$U")" "$KADB" 2>/dev/null || true
fi

# rebuild the app-menu cache so the hidden Kali links + new kOS icons show
asuser kbuildsycoca6 >/dev/null 2>&1 || asuser kbuildsycoca5 >/dev/null 2>&1 || true

echo
echo "============================================================"
echo " kOS system setup done. Pick a desktop look with one command:"
echo "   kos theme lamplight     # warm, lamplit"
echo "   kos theme liquidglass   # cool frosted gray"
echo "   kos theme dark          # kOS dark (Breeze Dark)"
echo "   kos theme light         # kOS light (Breeze Light)"
echo
echo " (or set them by hand in System Settings > Colors & Themes —"
echo "  the schemes are listed as 'kOS Lamplight' and 'kOS Liquid Glass')"
echo "============================================================"
