#!/usr/bin/env python3
"""kOS Welcome — first-boot out-of-box experience.

Runs once on first login (via /etc/xdg/autostart). Greets the user, lets them
pick a desktop theme live, then marks itself done so it never shows again.
Guard file: ~/.config/kos/oobe-done
"""
import os
import sys
import subprocess
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib  # noqa: E402

VERSION = "1.1.0"
SITE = "https://kaidevious.github.io/kOS/"
APP_ID = "io.github.kaidevious.kOS.Welcome"

DONE_DIR = os.path.join(GLib.get_user_config_dir(), "kos")
DONE_FILE = os.path.join(DONE_DIR, "oobe-done")

LOGO_CANDIDATES = [
    "/usr/share/kos/kos-logo.png",
    "/usr/share/icons/hicolor/256x256/apps/io.github.kaidevious.kOS.png",
    "/app/share/kos/logo.png",
]

THEMES = [
    ("Lamplight", "lamplight", "Warm, lamplit amber"),
    ("Liquid Glass", "liquidglass", "Cool frosted gray"),
    ("Dark", "dark", "Classic kOS dark"),
    ("Light", "light", "Clean kOS light"),
]


def find_logo():
    for p in LOGO_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def mark_done():
    try:
        os.makedirs(DONE_DIR, exist_ok=True)
        with open(DONE_FILE, "w") as f:
            f.write("kOS OOBE completed\n")
    except Exception:
        pass


def apply_theme(key):
    try:
        subprocess.Popen(["kos", "theme", key])
    except Exception:
        pass


class Welcome(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Welcome to kOS")
        self.set_default_size(640, 620)
        self.set_resizable(False)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
        root.append(Adw.HeaderBar(show_end_title_buttons=False,
                                  show_start_title_buttons=False))

        self.carousel = Adw.Carousel(allow_scroll_wheel=False,
                                     allow_mouse_drag=False, vexpand=True)
        self.carousel.add(self._page_welcome())
        self.carousel.add(self._page_theme())
        self.carousel.add(self._page_done())
        root.append(self.carousel)

        dots = Adw.CarouselIndicatorDots(carousel=self.carousel,
                                         margin_top=6, margin_bottom=6)
        root.append(dots)

        # bottom button bar
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                      margin_start=18, margin_end=18, margin_top=6, margin_bottom=18)
        self.back_btn = Gtk.Button(label="Back")
        self.back_btn.connect("clicked", self._back)
        self.back_btn.set_sensitive(False)
        spacer = Gtk.Box(hexpand=True)
        self.next_btn = Gtk.Button(label="Next")
        self.next_btn.add_css_class("suggested-action")
        self.next_btn.add_css_class("pill")
        self.next_btn.connect("clicked", self._next)
        bar.append(self.back_btn)
        bar.append(spacer)
        bar.append(self.next_btn)
        root.append(bar)

        self.carousel.connect("page-changed", self._on_page)

    # --- pages ---
    def _centered(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14,
                      valign=Gtk.Align.CENTER, halign=Gtk.Align.CENTER,
                      margin_start=40, margin_end=40)
        return box

    def _page_welcome(self):
        box = self._centered()
        logo = find_logo()
        if logo:
            img = Gtk.Image.new_from_file(logo)
            img.set_pixel_size(120)
            box.append(img)
        t = Gtk.Label(label="Welcome to kOS")
        t.add_css_class("title-1")
        box.append(t)
        s = Gtk.Label(label="Kali, reimagined with KDE Plasma.")
        s.add_css_class("title-4")
        s.add_css_class("dim-label")
        box.append(s)
        blurb = Gtk.Label(
            label="Let's get your desktop set up. This only takes a moment.",
            wrap=True, justify=Gtk.Justification.CENTER, margin_top=6)
        blurb.add_css_class("dim-label")
        box.append(blurb)
        return box

    def _page_theme(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10,
                      valign=Gtk.Align.CENTER, margin_start=48, margin_end=48)
        t = Gtk.Label(label="Choose your look")
        t.add_css_class("title-2")
        t.set_margin_bottom(4)
        box.append(t)
        s = Gtk.Label(label="Pick one — it applies instantly. You can change it anytime.")
        s.add_css_class("dim-label")
        s.set_margin_bottom(10)
        box.append(s)

        group = None
        for name, key, desc in THEMES:
            row = Adw.ActionRow(title=name, subtitle=desc)
            radio = Gtk.CheckButton()
            if group is None:
                group = radio
            else:
                radio.set_group(group)
            radio.set_valign(Gtk.Align.CENTER)
            radio.connect("toggled", self._pick, key)
            row.add_prefix(radio)
            row.set_activatable_widget(radio)
            frame = Adw.PreferencesGroup()
            frame.add(row)
            box.append(frame)
        return box

    def _page_done(self):
        box = self._centered()
        check = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
        check.set_pixel_size(96)
        check.add_css_class("success")
        box.append(check)
        t = Gtk.Label(label="You're all set!")
        t.add_css_class("title-1")
        box.append(t)
        s = Gtk.Label(label="kOS is ready to go. Enjoy your new desktop.",
                      wrap=True, justify=Gtk.Justification.CENTER)
        s.add_css_class("dim-label")
        box.append(s)
        links = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                        halign=Gtk.Align.CENTER, margin_top=10)
        cc = Gtk.Button(label="Open Control Center")
        cc.add_css_class("pill")
        cc.connect("clicked", lambda *_: self._open_cc())
        web = Gtk.Button(label="Website")
        web.add_css_class("pill")
        web.connect("clicked", lambda *_: Gtk.UriLauncher(uri=SITE).launch(self, None, None))
        links.append(cc)
        links.append(web)
        box.append(links)
        return box

    # --- behavior ---
    def _pick(self, btn, key):
        if btn.get_active():
            apply_theme(key)

    def _index(self):
        return int(self.carousel.get_position())

    def _next(self, *_):
        i = self._index()
        n = self.carousel.get_n_pages()
        if i >= n - 1:
            self._finish()
            return
        self.carousel.scroll_to(self.carousel.get_nth_page(i + 1), True)

    def _back(self, *_):
        i = self._index()
        if i > 0:
            self.carousel.scroll_to(self.carousel.get_nth_page(i - 1), True)

    def _on_page(self, _c, index):
        last = self.carousel.get_n_pages() - 1
        self.back_btn.set_sensitive(index > 0)
        self.next_btn.set_label("Finish" if index == last else "Next")

    def _open_cc(self):
        try:
            subprocess.Popen(["kos-control-center"])
        except Exception:
            pass

    def _finish(self):
        mark_done()
        self.close()


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_activate(self):
        win = self.props.active_window or Welcome(self)
        win.present()


if __name__ == "__main__":
    # self-guard: if the OOBE already ran for this user, do nothing.
    if os.path.exists(DONE_FILE) and "--force" not in sys.argv:
        sys.exit(0)
    App().run(None)
