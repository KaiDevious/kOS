#!/bin/bash
# kOS repo bootstrap — adds the kOS signing key + apt repo, then refreshes apt.
# Usage:  curl -fsSL https://kaidevious.github.io/kOS/apt/install.sh | sudo bash
#
# After this runs once:  sudo apt install kos-desktop
set -e

KEY_URL="https://kaidevious.github.io/kOS/apt/kos-archive-keyring.gpg"
KEYRING="/usr/share/keyrings/kos-archive-keyring.gpg"
LIST="/etc/apt/sources.list.d/kos.list"
REPO="https://kaidevious.github.io/kOS/apt"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root:  curl -fsSL $REPO/install.sh | sudo bash" >&2
  exit 1
fi

echo ":: Adding the kOS signing key..."
mkdir -p /usr/share/keyrings
curl -fsSL "$KEY_URL" -o "$KEYRING"

echo ":: Adding the kOS repository..."
echo "deb [signed-by=$KEYRING] $REPO ./" > "$LIST"

echo ":: Refreshing apt..."
apt-get update

cat <<EOF

kOS repo is ready. Install it with:

    sudo apt install kos-desktop
    sudo kos setup

Then reboot. Updates after that are just:  sudo apt update && sudo apt upgrade
EOF
