#!/bin/bash
# Publish kos-desktop as a flat apt repository under docs/apt/ (served by GitHub
# Pages at https://kaidevious.github.io/kOS/apt). Unsigned — users add it with
# [trusted=yes]. Run build-deb.sh first so the .deb is current.
set -e
cd "$(dirname "$0")"                 # packaging/
APT="../docs/apt"
mkdir -p "$APT"
rm -f "$APT"/kos-desktop_*.deb
cp -f "$(ls -1 kos-desktop_*.deb | sort -V | tail -1)" "$APT/"

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

echo "apt repo published to docs/apt/:"
ls -la
