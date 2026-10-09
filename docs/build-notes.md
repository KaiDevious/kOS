# kOS build notes

## Base
- Kali Linux (rolling) with the **KDE Plasma** desktop selected during install.

## VM settings (VirtualBox)
- 8 GB RAM, 3–4 CPUs, 80 GB dynamic disk, 128 MB video (VMSVGA).
- Adapter 1: NAT (internet). Adapter 2: Host-only (SSH).

## Applying the kOS look
Run `sudo bash scripts/kos-setup.sh` from a checkout, then reboot and:
- set the wallpaper (`/usr/share/wallpapers/kOS/kos-dark.png` or `kos-light.png`)
- pick a Breeze Dark/Light global theme
- set the accent color to `#2C62CF`

## Building the ISO
- Built with penguins-eggs (`sudo eggs remaster`).
- Bootloaders come from the penguins-bootloaders release; if the download times out,
  fetch `bootloaders.tar.gz` manually and extract to `/usr/share/penguins-eggs/bootloaders/`.
- Installer (Calamares) + boot-menu branding lives under `/etc/penguins-eggs.d/branding.default/`.
