#!/bin/bash
# Publish kos-desktop as a SIGNED flat apt repository under docs/apt/ (served by
# GitHub Pages at https://kaidevious.github.io/kOS/apt).
#
# The repo is GPG-signed, so users add it WITHOUT [trusted=yes]:
#   deb [signed-by=/usr/share/keyrings/kos-archive-keyring.gpg] \
#       https://kaidevious.github.io/kOS/apt ./
#
# You need the kOS private signing key imported in your GPG keyring. Import it
# once with:  gpg --import kos-repo-private-key.asc
# The matching public key ships in docs/apt/kos-archive-keyring.gpg (.asc).
#
# Override the signing identity if needed:  KOS_SIGN_KEY=<keyid|email> ./build-apt-repo.sh
# Run build-deb.sh first so the .deb is current.
set -e
cd "$(dirname "$0")"                 # packaging/
APT="../docs/apt"
KEY="${KOS_SIGN_KEY:-kaidevious@users.noreply.github.com}"

# verify we can actually sign before touching anything
if ! gpg --list-secret-keys "$KEY" >/dev/null 2>&1; then
  echo "ERROR: no secret key for '$KEY' in your GPG keyring." >&2
  echo "Import the kOS signing key first:  gpg --import kos-repo-private-key.asc" >&2
  echo "Or point at another key:  KOS_SIGN_KEY=<keyid|email> $0" >&2
  exit 1
fi

mkdir -p "$APT"
rm -f "$APT"/kos-desktop_*.deb
cp -f "$(ls -1 kos-desktop_*.deb | sort -V | tail -1)" "$APT/"

# keep the shipped public keyring in sync with the signing key (binary + armored)
gpg --export        "$KEY" > "$APT/kos-archive-keyring.gpg"
gpg --armor --export "$KEY" > "$APT/kos-archive-keyring.asc"

cd "$APT"
dpkg-scanpackages --multiversion . > Packages
gzip -9 -kf Packages

cat > Release <<EOF
Origin: kOS
Label: kOS
Suite: stable
Codename: kos
Architectures: all
Components: main
Description: kOS desktop suite apt repository
Date: $(date -Ru | sed 's/+0000/GMT/')
EOF
{
  echo "MD5Sum:"
  for f in Packages Packages.gz; do printf " %s %16d %s\n" "$(md5sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"; done
  echo "SHA256:"
  for f in Packages Packages.gz; do printf " %s %16d %s\n" "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"; done
} >> Release

# --- sign it: InRelease (inline) + Release.gpg (detached) ---
rm -f InRelease Release.gpg
gpg --batch --yes --default-key "$KEY" --clearsign -o InRelease Release
gpg --batch --yes --default-key "$KEY" -abs       -o Release.gpg Release

echo "signed apt repo published to docs/apt/:"
ls -la
echo
echo "signed with key: $KEY"
