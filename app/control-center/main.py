#!/usr/bin/env python3
"""kOS Control Center — the hub for themes, tweaks, and system info."""
import os
import re
import json
import time
import platform
import hashlib
import threading
import subprocess
import urllib.request
from datetime import datetime
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib  # noqa: E402

APP_ID = "io.github.kaidevious.kOS"
VERSION = "1.3"
SITE = "https://kaidevious.github.io/kOS/"
REPO = "https://github.com/KaiDevious/kOS"
LATEST_URL = "https://kaidevious.github.io/kOS/apt/kos-latest.json"
LOGO_CANDIDATES = [
    "/app/share/kos/logo.png",
    "/usr/share/kos/kos-logo.png",
    "/usr/share/icons/hicolor/256x256/apps/io.github.kaidevious.kOS.png",
]

THEMES = [
    ("Lamplight", "lamplight", "Warm, lamplit amber"),
    ("Liquid Glass", "liquidglass", "Cool frosted gray"),
    ("Dark", "dark", "Classic kOS dark"),
    ("Light", "light", "Clean kOS light"),
]
WALLPAPERS = [
    ("Lamplight", "lamplight", "Warm amber"),
    ("Liquid Glass", "liquidglass", "Frosted gray"),
    ("Dark", "dark", "Deep kOS dark"),
    ("Light", "light", "Bright kOS light"),
]
ACCENTS = [("Amber", "amber", "217,154,78"), ("Slate", "slate", "154,161,173"),
           ("Blue", "blue", "74,134,240"), ("Green", "green", "46,204,113"),
           ("Purple", "purple", "155,89,182"), ("Red", "red", "231,76,60")]

DIAG_COOLDOWN = 300  # seconds between diagnostics sends
DIAG_STATE = os.path.expanduser("~/.cache/kos/last-diag")


def _read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return ""


def read_diag_url():
    """Opt-in diagnostics endpoint from /etc/kos/config: DIAG_URL=..."""
    for line in _read_file("/etc/kos/config").splitlines():
        line = line.strip()
        if line.startswith("DIAG_URL"):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def gather_diag(theme=None):
    """Non-personal system info only — no files, usernames, or IPs."""
    d = {}
    d["kOS"] = kos_info()[0] or VERSION
    mid = (_read_file("/etc/machine-id").strip()
           or _read_file("/var/lib/dbus/machine-id").strip())
    d["id"] = hashlib.sha256(mid.encode()).hexdigest()[:12] if mid else "unknown"
    d["kernel"] = platform.release()
    d["arch"] = platform.machine()
    d["desktop"] = os.environ.get("XDG_CURRENT_DESKTOP", "")
    ci = _read_file("/proc/cpuinfo")
    m = re.search(r"model name\s*:\s*(.+)", ci)
    d["cpu"] = (m.group(1).strip() if m else "unknown")
    d["cores"] = str(ci.count("processor") or (os.cpu_count() or ""))
    mm = re.search(r"MemTotal:\s*(\d+)", _read_file("/proc/meminfo"))
    d["ram"] = (str(round(int(mm.group(1)) / 1048576, 1)) + " GB" if mm else "unknown")
    up = _read_file("/proc/uptime").split()
    if up:
        s = int(float(up[0]))
        d["uptime"] = "%dh %dm" % (s // 3600, (s % 3600) // 60)
    try:
        lp = subprocess.check_output(["sh", "-c", "lspci | grep -i vga"],
                                     text=True, stderr=subprocess.DEVNULL).strip()
        d["gpu"] = lp.split(":")[-1].strip() if lp else "unknown"
    except Exception:
        d["gpu"] = "unknown"
    try:
        d["virt"] = subprocess.check_output(["systemd-detect-virt"],
                                            text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        d["virt"] = "unknown"
    d["locale"] = os.environ.get("LANG", "")
    if theme:
        d["theme"] = theme
    d["time"] = datetime.now().strftime("%Y-%m-%d %H:%M")
    return d


def send_diag(url, data, cb):
    """POST a Discord-webhook-style JSON message off the UI thread."""
    def work():
        ok, msg = False, ""
        try:
            lines = "\n".join("%-9s %s" % (k + ":", v) for k, v in data.items())
            payload = json.dumps(
                {"content": "**kOS diagnostics**\n```\n" + lines + "\n```"}).encode()
            req = urllib.request.Request(
                url, data=payload,
                headers={"Content-Type": "application/json", "User-Agent": "kOS"})
            urllib.request.urlopen(req, timeout=10)
            ok = True
        except Exception as e:
            msg = str(e)
        GLib.idle_add(cb, ok, msg)
    threading.Thread(target=work, daemon=True).start()


def _diag_last():
    try:
        return float(_read_file(DIAG_STATE).strip() or 0)
    except Exception:
        return 0.0


def find_logo():
    for p in LOGO_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def run_host(args):
    """Run a command on the host (hop out of the sandbox when inside Flatpak)."""
    if os.path.exists("/.flatpak-info"):
        args = ["flatpak-spawn", "--host"] + args
    try:
        subprocess.Popen(args)
        return True
    except Exception:
        return False


def kos_info():
    code, ver = "", ""
    try:
        with open("/usr/share/kos/codename") as f:
            code = f.read().strip()
    except Exception:
        pass
    try:
        ver = subprocess.check_output(
            ["dpkg-query", "-W", "-f=${Version}", "kos-desktop"],
            text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        pass
    return ver, code


def kwrite(cfgfile, group, key, value):
    run_host(["kwriteconfig6", "--file", cfgfile, "--group", group,
              "--key", key, str(value)])


class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="kOS Control Center")
        self.set_default_size(600, 700)
        self._diag_timer = None

        self.toasts = Adw.ToastOverlay()
        self.set_content(self.toasts)
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toasts.set_child(root)

        self.stack = Adw.ViewStack()
        header = Adw.HeaderBar()
        switcher = Adw.ViewSwitcher(stack=self.stack, policy=Adw.ViewSwitcherPolicy.WIDE)
        header.set_title_widget(switcher)
        about_btn = Gtk.Button(icon_name="help-about-symbolic")
        about_btn.set_tooltip_text("About kOS")
        about_btn.connect("clicked", self._about)
        header.pack_end(about_btn)
        root.append(header)
        root.append(self.stack)

        self.stack.add_titled_with_icon(self._welcome(), "welcome", "Home", "user-home-symbolic")
        self.stack.add_titled_with_icon(self._themes(), "themes", "Themes", "applications-graphics-symbolic")
        self.stack.add_titled_with_icon(self._appearance(), "appearance", "Appearance", "preferences-desktop-wallpaper-symbolic")
        self.stack.add_titled_with_icon(self._tweaks(), "tweaks", "Tweaks", "preferences-system-symbolic")
        self.stack.add_titled_with_icon(self._system(), "system", "System", "computer-symbolic")

        # auto-check for updates on open so the Update button unlocks itself
        GLib.idle_add(self._check_updates, None)

    # --- Home ---
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
        ver, code = kos_info()
        tag = (f'kOS "{code}"' if code else "kOS") + (f"  ·  {ver}" if ver else "")
        vl = Gtk.Label(label=tag)
        vl.add_css_class("caption")
        vl.add_css_class("dim-label")
        clamp.append(vl)

        links = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                        halign=Gtk.Align.CENTER, margin_top=8)
        for label, uri, sug in (("Website", SITE, True), ("GitHub", REPO, False)):
            b = Gtk.Button(label=label)
            b.add_css_class("pill")
            if sug:
                b.add_css_class("suggested-action")
            b.connect("clicked", lambda _b, u=uri: self._open(u))
            links.append(b)
        clamp.append(links)

        grp = Adw.PreferencesGroup()
        grp.add(clamp)
        page.add(grp)

        actions = Adw.PreferencesGroup(title="Quick actions")
        for title_, subtitle, cmd, label in (
            ("Welcome wizard", "Re-run the first-boot setup", ["kos", "welcome"], "Open"),
            ("Surprise me", "Random accent color", ["kos", "accent", "random"], "Roll"),
            ("Celebrate", "A little rainbow in the terminal", ["konsole", "-e", "kos", "party"], "Party"),
        ):
            row = Adw.ActionRow(title=title_, subtitle=subtitle)
            btn = Gtk.Button(label=label, valign=Gtk.Align.CENTER)
            btn.add_css_class("flat")
            btn.connect("clicked", lambda _b, c=cmd, t=title_: (run_host(c), self._toast(t)))
            row.add_suffix(btn)
            row.set_activatable_widget(btn)
            actions.add(row)

        self.diag_row = Adw.ActionRow(
            title="Send diagnostics",
            subtitle="Share non-personal system info with the developer")
        self.diag_btn = Gtk.Button(label="Send", valign=Gtk.Align.CENTER)
        self.diag_btn.add_css_class("flat")
        self.diag_btn.connect("clicked", self._send_diag)
        self.diag_row.add_suffix(self.diag_btn)
        self.diag_row.set_activatable_widget(self.diag_btn)
        actions.add(self.diag_row)

        page.add(actions)
        # honor a cooldown that's still running from a previous send
        if time.time() - _diag_last() < DIAG_COOLDOWN:
            self._start_cooldown()
        return page

    # --- Themes ---
    def _themes(self):
        page = Adw.PreferencesPage()
        grp = Adw.PreferencesGroup(
            title="Desktop theme",
            description="Color scheme and matching wallpaper, applied live.")
        for name, key, desc in THEMES:
            row = Adw.ActionRow(title=name, subtitle=desc)
            btn = Gtk.Button(label="Apply", valign=Gtk.Align.CENTER)
            btn.add_css_class("flat")
            btn.connect("clicked", lambda _b, n=name, k=key:
                        (run_host(["kos", "theme", k]), self._toast(f"Applied {n}")))
            row.add_suffix(btn)
            row.set_activatable_widget(btn)
            grp.add(row)
        page.add(grp)
        cyc = Adw.PreferencesGroup()
        row = Adw.ActionRow(title="Cycle themes", subtitle="Jump to the next look")
        btn = Gtk.Button(label="Next", valign=Gtk.Align.CENTER)
        btn.add_css_class("flat")
        btn.connect("clicked", lambda *_: (run_host(["kos", "next"]), self._toast("Next theme")))
        row.add_suffix(btn)
        row.set_activatable_widget(btn)
        cyc.add(row)
        page.add(cyc)
        return page

    # --- Appearance: wallpaper + accent ---
    def _appearance(self):
        page = Adw.PreferencesPage()
        wg = Adw.PreferencesGroup(
            title="Wallpaper",
            description="Set just the background (overrides the theme's default).")
        for name, key, desc in WALLPAPERS:
            row = Adw.ActionRow(title=name, subtitle=desc)
            btn = Gtk.Button(label="Set", valign=Gtk.Align.CENTER)
            btn.add_css_class("flat")
            btn.connect("clicked", lambda _b, n=name, k=key:
                        (run_host(["kos", "wallpaper", k]), self._toast(f"Wallpaper: {n}")))
            row.add_suffix(btn)
            row.set_activatable_widget(btn)
            wg.add(row)
        page.add(wg)

        ag = Adw.PreferencesGroup(title="Accent color",
                                  description="The highlight color across the desktop.")
        flow = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                           max_children_per_line=6, min_children_per_line=3,
                           homogeneous=True, column_spacing=10, row_spacing=10,
                           margin_top=10, margin_bottom=6, margin_start=6, margin_end=6)
        for label, key, rgb in ACCENTS:
            r, g, b = (int(x) for x in rgb.split(","))
            btn = Gtk.Button(label=label)
            btn.set_size_request(80, 44)
            btn.add_css_class("pill")
            btn.set_tooltip_text(label)
            try:
                css = Gtk.CssProvider()
                data = f"button {{ background: rgb({r},{g},{b}); color:#fff; }}"
                try:
                    css.load_from_data(data, -1)
                except TypeError:
                    css.load_from_data(data.encode())
                btn.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            except Exception:
                pass
            btn.connect("clicked", lambda _b, k=key, n=label:
                        (run_host(["kos", "accent", k]), self._toast(f"Accent: {n}")))
            flow.append(btn)
        ag.add(flow)
        page.add(ag)
        return page

    # --- Tweaks ---
    def _tweaks(self):
        page = Adw.PreferencesPage()
        grp = Adw.PreferencesGroup(
            title="Desktop behavior",
            description="Most of these take effect at your next login.")

        click = Adw.SwitchRow(title="Single-click to open",
                              subtitle="Open files and folders with one click")
        click.connect("notify::active", lambda r, _p:
                      kwrite("kdeglobals", "KDE", "SingleClick", "true" if r.get_active() else "false"))
        grp.add(click)

        snappy = Adw.SwitchRow(title="Snappy mode",
                               subtitle="Reduce animations — smoother in a VM")
        snappy.connect("notify::active", lambda r, _p:
                       kwrite("kdeglobals", "KDE", "AnimationDurationFactor",
                              "0.5" if r.get_active() else "1"))
        grp.add(snappy)

        night = Adw.SwitchRow(title="Night Light",
                              subtitle="Warmer colors in the evening")
        night.connect("notify::active", lambda r, _p:
                      kwrite("kwinrc", "NightColor", "Active", "true" if r.get_active() else "false"))
        grp.add(night)
        page.add(grp)

        auto = Adw.PreferencesGroup(title="Automation")
        dn = Adw.SwitchRow(title="Day / night theme",
                           subtitle="Warm wallpaper by day, dark by night")
        dn.connect("notify::active", lambda r, _p:
                   (run_host(["kos", "auto", "on" if r.get_active() else "off"]),
                    self._toast("Day/night: " + ("on" if r.get_active() else "off"))))
        auto.add(dn)
        page.add(auto)
        return page

    # --- System ---
    def _system(self):
        page = Adw.PreferencesPage()
        ver, code = kos_info()
        info = Adw.PreferencesGroup(title="About")
        info.add(Adw.ActionRow(title="Codename", subtitle=code or "—"))
        info.add(Adw.ActionRow(title="Version", subtitle=ver or "—"))
        info.add(Adw.ActionRow(title="Base", subtitle="Kali Linux · KDE Plasma"))
        page.add(info)

        upd = Adw.PreferencesGroup(title="Updates")
        self.check_row = Adw.ActionRow(title="Check for updates", subtitle="Look for a newer kOS")
        self.check_spin = Gtk.Spinner(valign=Gtk.Align.CENTER)
        self.check_spin.set_visible(False)
        self.check_row.add_suffix(self.check_spin)
        self.check_btn = Gtk.Button(label="Check", valign=Gtk.Align.CENTER)
        self.check_btn.add_css_class("flat")
        self.check_btn.connect("clicked", self._check_updates)
        self.check_row.add_suffix(self.check_btn)
        upd.add(self.check_row)
        r2 = Adw.ActionRow(title="Update kOS", subtitle="Check for updates first")
        self.update_row = r2
        self.update_btn = Gtk.Button(label="Update", valign=Gtk.Align.CENTER)
        self.update_btn.add_css_class("flat")
        self.update_btn.set_sensitive(False)   # locked until a check finds an update
        self.update_btn.connect("clicked", lambda *_: run_host(["konsole", "-e", "bash", "-c",
            "echo 'Updating kOS…'; sudo apt update && sudo apt install --only-upgrade -y kos-desktop; "
            "echo; echo 'Done.'; read -p 'Press Enter to close…'"]))
        r2.add_suffix(self.update_btn)
        upd.add(r2)
        page.add(upd)

        maint = Adw.PreferencesGroup(title="Maintenance")
        mr1 = Adw.ActionRow(title="Repair install",
                            subtitle="Check & auto-fix common problems")
        mb1 = Gtk.Button(label="Repair", valign=Gtk.Align.CENTER)
        mb1.add_css_class("flat")
        mb1.connect("clicked", lambda *_: run_host(["konsole", "-e", "bash", "-c",
            "sudo kos doctor; echo; read -p 'Press Enter to close…'"]))
        mr1.add_suffix(mb1)
        maint.add(mr1)
        mr2 = Adw.ActionRow(title="Free up space",
                            subtitle="Remove junk packages and clear caches")
        mb2 = Gtk.Button(label="Clean", valign=Gtk.Align.CENTER)
        mb2.add_css_class("flat")
        mb2.connect("clicked", lambda *_: run_host(["konsole", "-e", "bash", "-c",
            "kos clean; echo; read -p 'Press Enter to close…'"]))
        mr2.add_suffix(mb2)
        maint.add(mr2)
        page.add(maint)

        links = Adw.PreferencesGroup(title="Links")
        for label, uri in (("Website", SITE), ("GitHub", REPO),
                           ("Report a bug", REPO + "/issues"), ("Docs", REPO + "#readme")):
            row = Adw.ActionRow(title=label)
            btn = Gtk.Button(icon_name="adw-external-link-symbolic", valign=Gtk.Align.CENTER)
            btn.add_css_class("flat")
            btn.connect("clicked", lambda _b, u=uri: self._open(u))
            row.add_suffix(btn)
            row.set_activatable_widget(btn)
            links.add(row)
        page.add(links)
        return page

    # --- update check (spinner, then verdict) ---
    def _check_updates(self, _button):
        self.check_btn.set_sensitive(False)
        self.check_spin.set_visible(True)
        self.check_spin.start()
        self.check_row.set_subtitle("Checking…")
        threading.Thread(target=self._check_worker, daemon=True).start()

    def _check_worker(self):
        res = {"ok": False}
        try:
            req = urllib.request.Request(LATEST_URL, headers={"User-Agent": "kOS"})
            with urllib.request.urlopen(req, timeout=8) as r:
                data = json.load(r)
            rv = str(data.get("version", "")).strip()
            rc = str(data.get("codename", "")).strip()
            inst = kos_info()[0] or "0"
            try:
                newer = subprocess.call(
                    ["dpkg", "--compare-versions", rv, "gt", inst],
                    stderr=subprocess.DEVNULL) == 0
            except Exception:
                newer = bool(rv) and rv != inst
            res = {"ok": True, "newer": newer, "rv": rv, "rc": rc}
        except Exception:
            res = {"ok": False}
        GLib.idle_add(self._check_done, res)

    def _check_done(self, res):
        self.check_spin.stop()
        self.check_spin.set_visible(False)
        self.check_btn.set_sensitive(True)
        if not res.get("ok"):
            self.check_row.set_subtitle("Couldn't check — are you online?")
            self.update_btn.set_sensitive(False)
            self.update_btn.remove_css_class("suggested-action")
            self.update_row.set_subtitle("Check for updates first")
        elif res.get("newer"):
            rc, rv = res.get("rc"), res.get("rv")
            tag = (f'kOS "{rc}" {rv}' if rc else f"kOS {rv}")
            self.check_row.set_subtitle(f"Click Update to go to {tag}")
            self.update_btn.set_sensitive(True)
            self.update_btn.add_css_class("suggested-action")
            self.update_row.set_subtitle(f"Ready: {tag}")
        else:
            self.check_row.set_subtitle("No updates available.")
            self.update_btn.set_sensitive(False)
            self.update_btn.remove_css_class("suggested-action")
            self.update_row.set_subtitle("You're up to date")
        return False

    # --- send diagnostics (with a 5-minute cooldown) ---
    def _send_diag(self, _b):
        url = read_diag_url()
        if not url:
            self._toast("Diagnostics isn't set up on this system")
            return
        if time.time() - _diag_last() < DIAG_COOLDOWN:
            self._start_cooldown()
            return
        self.diag_btn.set_sensitive(False)
        self.diag_btn.set_label("Sending…")
        theme = _read_file(os.path.expanduser("~/.cache/kos/theme")).strip() or None
        send_diag(url, gather_diag(theme), self._diag_sent)

    def _diag_sent(self, ok, _msg):
        if ok:
            self._toast("Diagnostics sent — thanks!")
            try:
                os.makedirs(os.path.dirname(DIAG_STATE), exist_ok=True)
                with open(DIAG_STATE, "w") as f:
                    f.write(str(time.time()))
            except Exception:
                pass
            self._start_cooldown()
        else:
            self._toast("Couldn't send diagnostics — are you online?")
            self.diag_btn.set_sensitive(True)
            self.diag_btn.set_label("Send")
        return False

    def _start_cooldown(self):
        if self._diag_timer is None:
            self._diag_timer = GLib.timeout_add_seconds(1, self._tick_cooldown)
        self._tick_cooldown()

    def _tick_cooldown(self):
        remain = int(DIAG_COOLDOWN - (time.time() - _diag_last()))
        if remain <= 0:
            self.diag_btn.set_label("Send")
            self.diag_btn.set_sensitive(True)
            self._diag_timer = None
            return False
        self.diag_btn.set_sensitive(False)
        self.diag_btn.set_label("Wait %d:%02d" % (remain // 60, remain % 60))
        return True

    def _about(self, _b=None):
        ver, code = kos_info()
        verstr = (f'{ver} "{code}"' if ver and code else (ver or (f'"{code}"' if code else VERSION)))
        try:
            about = Adw.AboutWindow(
                transient_for=self, application_name="kOS",
                application_icon=APP_ID, version=verstr,
                developer_name="Kai", website=SITE, issue_url=REPO + "/issues",
                comments="Kali Linux, reimagined with the KDE Plasma desktop.",
                license_type=Gtk.License.GPL_3_0,
                copyright="Based on Kali Linux and KDE Plasma.")
            logo = find_logo()
            if logo:
                about.set_property("application-icon", APP_ID)
            about.present()
        except Exception:
            dlg = Gtk.MessageDialog(transient_for=self, modal=True,
                                    text="kOS", secondary_text=f"Version {verstr}\n{SITE}")
            dlg.add_button("Close", Gtk.ResponseType.CLOSE)
            dlg.connect("response", lambda d, _r: d.destroy())
            dlg.present()

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
