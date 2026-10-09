#!/bin/bash
# kOS v2 setup — run from the folder that holds this script and the assets:
#   cd ~/kos-assets && sudo bash kos-setup.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
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
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
rmmod pcspkr 2>/dev/null || true

say "3/8  fastfetch with the kOS logo"
apt-get install -y fastfetch >/dev/null 2>&1 || true
mkdir -p /usr/share/kos /etc/xdg/fastfetch
cp "$HERE/kos-ascii.txt" /usr/share/kos/kos.txt
cat > /etc/xdg/fastfetch/config.jsonc <<'JSON'
{
  "logo": { "source": "/usr/share/kos/kos.txt", "type": "file", "color": { "1": "blue" } },
  "modules": [
    {"type":"command","key":"OS","text":". /etc/os-release && echo $PRETTY_NAME $(uname -m)"},
    "kernel","uptime","packages","shell","de","wm","terminal","cpu","gpu","memory","disk","break","colors"
  ]
}
JSON

say "4/8  Wallpapers (dark + light)"
mkdir -p /usr/share/wallpapers/kOS/contents/images
cp "$HERE/wallpaper-dark.png"  /usr/share/wallpapers/kOS/kos-dark.png
cp "$HERE/wallpaper-light.png" /usr/share/wallpapers/kOS/kos-light.png
cp "$HERE/wallpaper-dark.png"  /usr/share/wallpapers/kOS/contents/images/3840x2160.png

say "5/8  Login screen background (SDDM)"
if [ -d /usr/share/sddm/themes/breeze ]; then
  rm -rf /usr/share/sddm/themes/kos
  cp -r /usr/share/sddm/themes/breeze /usr/share/sddm/themes/kos
  cp "$HERE/login-dark.png" /usr/share/sddm/themes/kos/kos-login.png
  printf '[General]\nbackground=/usr/share/sddm/themes/kos/kos-login.png\ntype=image\n' > /usr/share/sddm/themes/kos/theme.conf.user
  mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=kos\n' > /etc/sddm.conf.d/zz-kos.conf
else
  echo "   (breeze SDDM theme not found — skipping; we can set this up manually)"
fi

say "6/8  Broadcast: terminal MOTD + desktop notifications"
# MOTD for login/SSH shells
cat > /etc/profile.d/kos-motd.sh <<EOF2
case \$- in *i*)
  curl -fsS --max-time 2 "$REPO/message.txt?t=\$(date +%s)" 2>/dev/null && echo ;;
esac
EOF2
# also show in Konsole (non-login) via bash.bashrc
grep -q kos-motd /etc/bash.bashrc 2>/dev/null || echo '[ -r /etc/profile.d/kos-motd.sh ] && . /etc/profile.d/kos-motd.sh' >> /etc/bash.bashrc
# notifier daemon
cat > /usr/local/bin/kos-notify.sh <<EOF3
#!/bin/bash
STATE="\$HOME/.cache/kos-last-notify"; mkdir -p "\$HOME/.cache"; sleep 15
while true; do
  MSG=\$(curl -fsS --max-time 5 "$REPO/notify.txt?t=\$(date +%s)" 2>/dev/null)
  if [ -n "\$MSG" ] && [ "\$MSG" != "\$(cat "\$STATE" 2>/dev/null)" ]; then
    notify-send "kOS" "\$MSG"; echo "\$MSG" > "\$STATE"
  fi
  sleep 60
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

say "7/8  Colored zsh for new users + you"
apt-get install -y zsh zsh-syntax-highlighting zsh-autosuggestions >/dev/null 2>&1 || true
cat > /etc/skel/.zshrc <<'ZRC'
HISTFILE=~/.zsh_history; HISTSIZE=10000; SAVEHIST=10000; setopt share_history
autoload -Uz compinit && compinit
PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f$ '
[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZRC
cp /etc/skel/.zshrc "$UH/.zshrc" 2>/dev/null && chown "$U:$U" "$UH/.zshrc"
chsh -s "$(which zsh)" "$U" 2>/dev/null || true

say "8/8  App-menu icon"
cp "$HERE/logo-dark.png" /usr/share/icons/hicolor/256x256/apps/kos.png 2>/dev/null || true

echo
echo "============================================================"
echo " kOS system setup done. Reboot, then finish the 3 GUI steps:"
echo "   • Wallpaper:  right-click desktop > Set Wallpaper >"
echo "       /usr/share/wallpapers/kOS/kos-dark.png (or kos-light.png)"
echo "   • Theme:      System Settings > Colors & Themes > Global Theme"
echo "       pick Breeze Dark or Breeze Light to match your wallpaper"
echo "   • Accent:     System Settings > Colors > custom accent  #2C62CF"
echo "============================================================"
