#!/usr/bin/env python3
"""kOS Control Center — welcome hub + desktop theme switcher."""
import os
import subprocess
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib  # noqa: E402

APP_ID = "io.github.kaidevious.kOS"
VERSION = "1.0.0"
SITE = "https://kaidevious.github.io/kOS/"
REPO = "https://github.com/KaiDevious/kOS"
LOGO_CANDIDATES = [
    "/app/share/kos/logo.png",                                      # flatpak
    "/usr/share/kos/kos-logo.png",                                  # native .deb
    "/usr/share/icons/hicolor/256x256/apps/io.github.kaidevious.kOS.png",
]


def find_logo():
    for p in LOGO_CANDIDATES:
        if os.path.exists(p):
            return p
    return None

THEMES = [
    ("Lamplight", "lamplight", "Warm, lamplit"),
    ("Liquid Glass", "liquidglass", "Cool frosted gray"),
    ("Dark", "dark", "kOS dark"),
    ("Light", "light", "kOS light"),
]


def run_host(args):
    """Run a command on the host (hop out of the sandbox when inside Flatpak)."""
    if os.path.exists("/.flatpak-info"):
        args = ["flatpak-spawn", "--host"] + args
    try:
        subprocess.Popen(args)
        return True
    except Exception:
        return False


class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="kOS Control Center")
        self.set_default_size(560, 660)

        self.toasts = Adw.ToastOverlay()
        self.set_content(self.toasts)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toasts.set_child(root)

        stack = Adw.ViewStack()
        header = Adw.HeaderBar()
        switcher = Adw.ViewSwitcher(stack=stack, policy=Adw.ViewSwitcherPolicy.WIDE)
        header.set_title_widget(switcher)
        root.append(header)
        root.append(stack)

        stack.add_titled_with_icon(self._welcome(), "welcome", "Welcome", "user-home-symbolic")
        stack.add_titled_with_icon(self._themes(), "themes", "Themes", "applications-graphics-symbolic")

    # --- Welcome page ---
    def _welcome(self):
        page = Adw.PreferencesPage()
        clamp = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14,
                        margin_top=28, margin_bottom=28, halign=Gtk.Align.CENTER)

        logo = find_logo()
        if logo:
            img = Gtk.Image.new_from_file(logo)
            img.set_pixel_size(96)
            clamp.append(img)

        title = Gtk.Label(label="kOS")
        title.add_css_class("title-1")
        clamp.append(title)

        sub = Gtk.Label(label="Kali, reimagined with KDE Plasma.")
        sub.add_css_class("dim-label")
        clamp.append(sub)

        ver = Gtk.Label(label=f"Control Center {VERSION}")
        ver.add_css_class("caption")
        ver.add_css_class("dim-label")
        clamp.append(ver)

        links = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                        halign=Gtk.Align.CENTER, margin_top=8)
        site_btn = Gtk.Button(label="Website")
        site_btn.add_css_class("pill")
        site_btn.add_css_class("suggested-action")
        site_btn.connect("clicked", lambda *_: self._open(SITE))
        repo_btn = Gtk.Button(label="GitHub")
        repo_btn.add_css_class("pill")
        repo_btn.connect("clicked", lambda *_: self._open(REPO))
        links.append(site_btn)
        links.append(repo_btn)
        clamp.append(links)

        group = Adw.PreferencesGroup()
        group.add(clamp)
        page.add(group)
        return page

    # --- Themes page ---
    def _themes(self):
        page = Adw.PreferencesPage()
        group = Adw.PreferencesGroup(
            title="Desktop theme",
            description="Switch the kOS look live — color scheme and wallpaper together.",
        )
        for name, key, desc in THEMES:
            row = Adw.ActionRow(title=name, subtitle=desc)
            btn = Gtk.Button(label="Apply")
            btn.add_css_class("flat")
            btn.set_valign(Gtk.Align.CENTER)
            btn.connect("clicked", self._apply, name, key)
            row.add_suffix(btn)
            row.set_activatable_widget(btn)
            group.add(row)
        page.add(group)
        return page

    def _apply(self, _btn, name, key):
        ok = run_host(["kos", "theme", key])
        if ok:
            self._toast(f"Applied {name}")
        else:
            self._toast("Couldn't run 'kos theme' — is kos-desktop installed?")

    def _open(self, uri):
        Gtk.UriLauncher(uri=uri).launch(self, None, None)

    def _toast(self, text):
        self.toasts.add_toast(Adw.Toast(title=text, timeout=2))


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_activate(self):
        win = self.props.active_window or Window(self)
        win.present()


if __name__ == "__main__":
    App().run(None)
