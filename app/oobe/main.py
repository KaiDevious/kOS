#!/usr/bin/env python3
"""kOS Welcome — first-boot out-of-box experience.

Runs once on first login (via /etc/xdg/autostart). Walks the user through
personalizing their desktop, then marks itself done so it never shows again.
Guard file: ~/.config/kos/oobe-done
"""
import os
import sys
import subprocess
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib, Gdk  # noqa: E402

VERSION = "1.1.0"
SITE = "https://kaidevious.github.io/kOS/"
APP_ID = "io.github.kaidevious.kOS.Welcome"

CFG_DIR = os.path.join(GLib.get_user_config_dir(), "kos")
DONE_FILE = os.path.join(CFG_DIR, "oobe-done")
NAME_FILE = os.path.join(CFG_DIR, "name")

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

WP_DIR = "/usr/share/wallpapers/kOS"
WALLPAPERS = [
    ("Lamplight", f"{WP_DIR}/kos-lamplight.png", "Warm amber"),
    ("Liquid Glass", f"{WP_DIR}/kos-liquidglass.png", "Frosted gray"),
    ("Dark", f"{WP_DIR}/kos-dark.png", "Deep kOS dark"),
    ("Light", f"{WP_DIR}/kos-light.png", "Bright kOS light"),
]

# (label, "R,G,B")
ACCENTS = [
    ("Amber", "217,154,78"),
    ("Slate", "154,161,173"),
    ("Blue", "74,134,240"),
    ("Green", "46,204,113"),
    ("Purple", "155,89,182"),
    ("Red", "231,76,60"),
]


# ---------- helpers ----------
def find_logo():
    for p in LOGO_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def _ensure_cfg():
    try:
        os.makedirs(CFG_DIR, exist_ok=True)
    except Exception:
        pass


def mark_done():
    _ensure_cfg()
    try:
        with open(DONE_FILE, "w") as f:
            f.write("kOS OOBE completed\n")
    except Exception:
        pass


def save_name(name):
    _ensure_cfg()
    try:
        with open(NAME_FILE, "w") as f:
            f.write(name.strip() + "\n")
    except Exception:
        pass


def _bin_on_path(name):
    return any(os.access(os.path.join(p, name), os.X_OK)
               for p in os.environ.get("PATH", "").split(os.pathsep))


def _kwrite_bin():
    for b in ("kwriteconfig6", "kwriteconfig5"):
        if _bin_on_path(b):
            return b
    return None


def kwrite(cfgfile, group, key, value):
    """Write a KDE setting (applies on next login, some live)."""
    b = _kwrite_bin()
    if not b:
        return
    try:
        subprocess.Popen([b, "--file", cfgfile, "--group", group,
                          "--key", key, str(value)])
    except Exception:
        pass


def apply_theme(key):
    try:
        subprocess.Popen(["kos", "theme", key])
    except Exception:
        pass


def set_wallpaper(path):
    if os.path.exists(path):
        try:
            subprocess.Popen(["plasma-apply-wallpaperimage", path])
        except Exception:
            pass


def set_accent(rgb):
    kwrite("kdeglobals", "General", "AccentColor", rgb)


def set_nightlight(on):
    kwrite("kwinrc", "NightColor", "Active", "true" if on else "false")


def set_hostname(name):
    name = name.strip()
    if not name or not _bin_on_path("pkexec"):
        return
    try:
        subprocess.Popen(["pkexec", "hostnamectl", "set-hostname", name])
    except Exception:
        pass


# ---------- UI ----------
class Welcome(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Welcome to kOS")
        self.set_default_size(660, 660)
        self.set_resizable(False)
        self.name_row = None
        self.host_row = None

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
        root.append(Adw.HeaderBar(show_end_title_buttons=False,
                                  show_start_title_buttons=False))

        self.carousel = Adw.Carousel(allow_scroll_wheel=False,
                                     allow_mouse_drag=False, vexpand=True)
        for page in (self._page_welcome(), self._page_identity(),
                     self._page_theme(), self._page_accent(),
                     self._page_wallpaper(), self._page_behavior(),
                     self._page_done()):
            self.carousel.add(page)
        root.append(self.carousel)

        root.append(Adw.CarouselIndicatorDots(carousel=self.carousel,
                                              margin_top=6, margin_bottom=6))

        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                      margin_start=18, margin_end=18, margin_top=6, margin_bottom=18)
        self.back_btn = Gtk.Button(label="Back")
        self.back_btn.connect("clicked", self._back)
        self.back_btn.set_sensitive(False)
        self.next_btn = Gtk.Button(label="Next")
        self.next_btn.add_css_class("suggested-action")
        self.next_btn.add_css_class("pill")
        self.next_btn.connect("clicked", self._next)
        bar.append(self.back_btn)
        bar.append(Gtk.Box(hexpand=True))
        bar.append(self.next_btn)
        root.append(bar)

        self.carousel.connect("page-changed", self._on_page)

    # --- layout helpers ---
    def _centered(self):
        return Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14,
                       valign=Gtk.Align.CENTER, halign=Gtk.Align.CENTER,
                       margin_start=40, margin_end=40)

    def _titled(self, title, subtitle):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10,
                      valign=Gtk.Align.CENTER, margin_start=48, margin_end=48)
        t = Gtk.Label(label=title)
        t.add_css_class("title-2")
        box.append(t)
        s = Gtk.Label(label=subtitle, wrap=True,
                      justify=Gtk.Justification.CENTER)
        s.add_css_class("dim-label")
        s.set_margin_bottom(8)
        box.append(s)
        return box

    def _radio_list(self, items, cb):
        """items: list of (title, subtitle, payload)."""
        wrap = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        group = None
        for title, subtitle, payload in items:
            row = Adw.ActionRow(title=title, subtitle=subtitle)
            radio = Gtk.CheckButton()
            group = group or radio
            if radio is not group:
                radio.set_group(group)
            radio.set_valign(Gtk.Align.CENTER)
            radio.connect("toggled", cb, payload)
            row.add_prefix(radio)
            row.set_activatable_widget(radio)
            g = Adw.PreferencesGroup()
            g.add(row)
            wrap.append(g)
        return wrap

    # --- pages ---
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
            label="Let's make this desktop yours. It only takes a minute.",
            wrap=True, justify=Gtk.Justification.CENTER, margin_top=6)
        blurb.add_css_class("dim-label")
        box.append(blurb)
        return box

    def _page_identity(self):
        box = self._titled("Make it yours",
                            "What should we call you? (optional)")
        grp = Adw.PreferencesGroup()
        self.name_row = Adw.EntryRow(title="Your name")
        grp.add(self.name_row)
        self.host_row = Adw.EntryRow(title="Computer name (optional)")
        grp.add(self.host_row)
        box.append(grp)
        return box

    def _page_theme(self):
        box = self._titled("Choose your look",
                            "Pick one — it applies instantly. Change it anytime.")
        box.append(self._radio_list(
            [(n, d, k) for n, k, d in THEMES], self._pick_theme))
        return box

    def _page_accent(self):
        box = self._titled("Accent color",
                            "The highlight color across your desktop.")
        flow = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                           max_children_per_line=6, min_children_per_line=3,
                           homogeneous=True, column_spacing=10, row_spacing=10,
                           halign=Gtk.Align.CENTER)
        for label, rgb in ACCENTS:
            r, g, b = (int(x) for x in rgb.split(","))
            btn = Gtk.Button(label=label)
            btn.set_size_request(72, 48)
            btn.add_css_class("pill")
            btn.set_tooltip_text(label)
            # color the swatch; tolerate any CSS API differences across GTK builds
            try:
                css = Gtk.CssProvider()
                data = (f"button {{ background: rgb({r},{g},{b});"
                        f" color: #fff; font-size: 0; min-height: 44px; }}")
                try:
                    css.load_from_data(data, -1)
                except TypeError:
                    css.load_from_data(data.encode())
                btn.get_style_context().add_provider(
                    css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            except Exception:
                pass
            btn.connect("clicked", lambda _b, c=rgb: set_accent(c))
            flow.append(btn)
        box.append(flow)
        return box

    def _page_wallpaper(self):
        box = self._titled("Pick a wallpaper",
                            "Optional — overrides the theme's default background.")
        box.append(self._radio_list(
            [(n, d, p) for n, p, d in WALLPAPERS], self._pick_wp))
        return box

    def _page_behavior(self):
        box = self._titled("Desktop behavior",
                            "A few tweaks. These apply next time you log in.")
        grp = Adw.PreferencesGroup()
        click = Adw.SwitchRow(title="Single-click to open",
                              subtitle="Open files and folders with one click")
        click.connect("notify::active", lambda r, _p:
                      kwrite("kdeglobals", "KDE", "SingleClick",
                             "true" if r.get_active() else "false"))
        grp.add(click)
        snappy = Adw.SwitchRow(title="Snappy mode",
                               subtitle="Reduce animations — smoother in a VM")
        snappy.connect("notify::active", lambda r, _p:
                       kwrite("kdeglobals", "KDE", "AnimationDurationFactor",
                              "0.5" if r.get_active() else "1"))
        grp.add(snappy)
        night = Adw.SwitchRow(title="Night Light",
                              subtitle="Warmer colors in the evening, easier on the eyes")
        night.connect("notify::active", lambda r, _p:
                      set_nightlight(r.get_active()))
        grp.add(night)
        box.append(grp)
        return box

    def _page_done(self):
        box = self._centered()
        check = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
        check.set_pixel_size(96)
        check.add_css_class("success")
        box.append(check)
        self.done_title = Gtk.Label(label="You're all set!")
        self.done_title.add_css_class("title-1")
        box.append(self.done_title)
        s = Gtk.Label(label="kOS is ready to go. Enjoy your new desktop.",
                      wrap=True, justify=Gtk.Justification.CENTER)
        s.add_css_class("dim-label")
        box.append(s)
        links = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                        halign=Gtk.Align.CENTER, margin_top=10)
        cc = Gtk.Button(label="Open Control Center")
        cc.add_css_class("pill")
        cc.connect("clicked", lambda *_: self._run("kos-control-center"))
        web = Gtk.Button(label="Website")
        web.add_css_class("pill")
        web.connect("clicked", lambda *_:
                    Gtk.UriLauncher(uri=SITE).launch(self, None, None))
        links.append(cc)
        links.append(web)
        box.append(links)
        return box

    # --- behavior ---
    def _pick_theme(self, btn, key):
        if btn.get_active():
            apply_theme(key)

    def _pick_wp(self, btn, path):
        if btn.get_active():
            set_wallpaper(path)

    def _index(self):
        return int(self.carousel.get_position())

    def _next(self, *_):
        i, n = self._index(), self.carousel.get_n_pages()
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
        # personalize the finish greeting
        if index == last and self.name_row is not None:
            nm = self.name_row.get_text().strip()
            self.done_title.set_label(f"You're all set, {nm}!" if nm
                                      else "You're all set!")

    def _run(self, *argv):
        try:
            subprocess.Popen(list(argv))
        except Exception:
            pass

    def _finish(self):
        if self.name_row is not None:
            nm = self.name_row.get_text().strip()
            if nm:
                save_name(nm)
        if self.host_row is not None:
            hn = self.host_row.get_text().strip()
            if hn:
                set_hostname(hn)
        mark_done()
        self.close()


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID,
                         flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_activate(self):
        win = self.props.active_window or Welcome(self)
        win.present()


if __name__ == "__main__":
    if os.path.exists(DONE_FILE) and "--force" not in sys.argv:
        sys.exit(0)
    App().run(None)
