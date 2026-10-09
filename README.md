im still lazy so thanks claude for writing this

# kOS

A custom Linux distribution built on **Kali** with the **KDE Plasma** desktop. It runs your Windows apps, opens your Apple files, comes with security tools, and has its own clean look.

**Note:** kOS is a personal project made for fun and learning. Because it's based on Kali, it includes security tools. Only use those on devices and networks you own or have permission to test.

## What it does

- **Runs Windows apps.** Wine is built in, so most `.exe` files work.
- **Works with Apple files.** Opens iPhone photos (HEIC) and common Mac file types.
- **Has security tools built in.** The Kali tool set (nmap, Wireshark, Burp, Ghidra, and more).
- **Can send announcements.** A built-in message-of-the-day and pop-up notifications, controlled from one place. ([how it works](https://github.com/KaiDevious/kos-motd-notif-sender))
- **Looks custom.** Dark and light themes, plus a matching wallpaper, boot screen, login screen, and terminal logo.
- **Small quality-of-life fixes.** No system beep, reliable networking, and a colored terminal.

## Screenshots

| Dark | Light |
|------|-------|
| ![dark](branding/wallpaper-dark.png) | ![light](branding/wallpaper-light.png) |

## How to install

Pick whichever fits you.

### Option 1 — Install the full kOS (easiest)

1. Download `kOS.iso` from the [Releases](https://github.com/KaiDevious/kOS/releases) page.
2. Install it like any Linux ISO, in a virtual machine or on a real computer.

### Option 2 — Add kOS to a Kali you already have

1. Install Kali and choose the **KDE Plasma** desktop.
2. Download `kos-desktop_1.0.0.deb` from [Releases](https://github.com/KaiDevious/kOS/releases) (or the `packaging/` folder).
3. Open a terminal where the file is and run:
   ```bash
   sudo apt install ./kos-desktop_1.0.0.deb
   sudo kos-setup
   ```
4. Reboot.

That's it. The package installs the kOS look, the announcement tools, and the apps it needs. To change the announcement settings later, edit `/etc/kos/config`.

### Option 3 — Build it yourself from the source

1. Install Kali with the **KDE Plasma** desktop.
2. Run:
   ```bash
   git clone https://github.com/KaiDevious/kOS
   cd kOS
   sudo bash scripts/kos-setup.sh
   ```
3. Reboot.
4. Finish the look: right-click the desktop to set the wallpaper, then open System Settings to pick a Breeze Dark or Light theme and set the accent color.

## What's in this repo

```
branding/    wallpapers, logos, boot screen, login screen, terminal logo
scripts/     kos-setup.sh — applies the whole kOS look and tweaks
installer/   the installer and boot-menu branding used to build the ISO
packaging/   kos-desktop.deb — branding, announcement tools, and kos-setup in one package
docs/        notes on how kOS is built
```

## Credits

Built by Kai. Based on [Kali Linux](https://www.kali.org/) and [KDE Plasma](https://kde.org/). The ISO is built with [penguins-eggs](https://penguins-eggs.net/).

## License

The kOS code, scripts, and configs are **GPL-3.0** (see [`LICENSE`](LICENSE)). The software kOS bundles keeps its own licenses. The kOS name and logo are not covered by that license — please don't ship a modified build and call it "kOS."
