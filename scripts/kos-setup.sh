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

# point the KDE application launcher (Kickoff) at the kOS logo instead of the Kali dragon
APPLETS="$UH/.config/plasma-org.kde.plasma.desktop-appletsrc"
KW="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
if [ -f "$APPLETS" ] && [ -n "$KW" ]; then
  # find each launcher applet's group header, e.g. [Containments][21][Applets][35]
  awk '/^\[/{hdr=$0} /^plugin=org\.kde\.plasma\.(kickoff|kicker|kickerdash)/{print hdr}' "$APPLETS" | while read -r grp; do
    [ -n "$grp" ] || continue
    gargs=""; for g in $(printf '%s' "$grp" | sed 's/^\[//; s/\]$//; s/\]\[/ /g'); do gargs="$gargs --group $g"; done
    sudo -u "$U" $KW --file "$APPLETS" $gargs --group Configuration --group General \
      --key icon /usr/share/icons/hicolor/256x256/apps/kos-menu.png 2>/dev/null || true
    # default favorites: kOS apps in, Kali out (replaces the stock favorites list)
    sudo -u "$U" $KW --file "$APPLETS" $gargs --group Configuration --group General \
      --key favorites "io.github.kaidevious.kOS.desktop,kos-website.desktop,kos-bugs.desktop,kos-docs.desktop,kos-github.desktop,org.kde.dolphin.desktop,firefox-esr.desktop,org.kde.konsole.desktop,systemsettings.desktop" 2>/dev/null || true
    sudo -u "$U" $KW --file "$APPLETS" $gargs --group Configuration --group General \
      --key favoritesPortedToKAstats false 2>/dev/null || true
  done
  chown "$U":"$(id -gn "$U" 2>/dev/null || echo "$U")" "$APPLETS" 2>/dev/null || true
fi

say "App menu: hide Kali web links, add kOS ones"
# hide Kali's app-menu web shortcuts (Kali Bugs, Docs, Forums, Tools, ...)
DFE="$(command -v desktop-file-edit || true)"
for f in /usr/share/applications/kali-*.desktop; do
  [ -f "$f" ] || continue
  if [ -n "$DFE" ]; then
    "$DFE" --set-key=NoDisplay --set-value=true "$f" 2>/dev/null || true
  else
    grep -q '^NoDisplay=' "$f" || sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$f"
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
