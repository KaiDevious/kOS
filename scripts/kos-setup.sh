#!/bin/bash
# kOS v2 setup — run from the folder that holds this script and the assets:
#   cd ~/kos-assets && sudo bash kos-setup.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# assets live in ../branding when run from the repo, or beside the script in the flat kit
ASSETS="$HERE"; [ -d "$HERE/../branding" ] && ASSETS="$(cd "$HERE/../branding" && pwd)"
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
cp "$ASSETS/kos-ascii.txt" /usr/share/kos/kos.txt
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
cp "$ASSETS/wallpaper-dark.png"  /usr/share/wallpapers/kOS/kos-dark.png
cp "$ASSETS/wallpaper-light.png" /usr/share/wallpapers/kOS/kos-light.png
cp "$ASSETS/wallpaper-dark.png"  /usr/share/wallpapers/kOS/contents/images/3840x2160.png

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
cp "$ASSETS/logo-dark.png" /usr/share/icons/hicolor/256x256/apps/kos.png 2>/dev/null || true

say "GRUB boot menu branding"
cp /etc/default/grub /etc/default/grub.kosbak 2>/dev/null || true
cp "$ASSETS/splash.png" /usr/share/kos/grub-bg.png 2>/dev/null || true
sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="kOS"|' /etc/default/grub
grep -q '^GRUB_DISTRIBUTOR' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="kOS"' >> /etc/default/grub
grep -q '^GRUB_BACKGROUND' /etc/default/grub \
  && sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/usr/share/kos/grub-bg.png"|' /etc/default/grub \
  || echo 'GRUB_BACKGROUND="/usr/share/kos/grub-bg.png"' >> /etc/default/grub
grep -q '^GRUB_TIMEOUT_STYLE' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
grep -q 'splash' /etc/default/grub || sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
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

echo
echo "============================================================"
echo " kOS system setup done. Reboot, then finish the 3 GUI steps:"
echo "   • Wallpaper:  right-click desktop > Set Wallpaper >"
echo "       /usr/share/wallpapers/kOS/kos-dark.png (or kos-light.png)"
echo "   • Theme:      System Settings > Colors & Themes > Global Theme"
echo "       pick Breeze Dark or Breeze Light to match your wallpaper"
echo "   • Accent:     System Settings > Colors > custom accent  #2C62CF"
echo "============================================================"
