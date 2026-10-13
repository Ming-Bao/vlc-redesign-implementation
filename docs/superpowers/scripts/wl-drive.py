#!/usr/bin/python3 -I
"""Drive the dev build of VLC on native Wayland inside a private headless GNOME Shell.

Run under its own D-Bus session so nothing touches the desktop session:

    dbus-run-session -- docs/superpowers/scripts/wl-drive.py OUTDIR STEP...

Steps (executed in order):
    vlc:ARG,ARG,...   start VLC (QT_QPA_PLATFORM=wayland) with extra args
    max               maximize the focused window (Super+Up)
    sleep:SECONDS
    shot:NAME         save OUTDIR/NAME.png from a Mutter ScreenCast stream
    move:X,Y          move the pointer to monitor coordinates
    click:X,Y         left click at monitor coordinates
    key:KEYSYM        press+release a keysym (e.g. space, Escape)
Writes OUTDIR/vlc.log and OUTDIR/shell.log.
"""
import os
import subprocess
import sys
import time

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
BUILD = os.path.join(REPO, "build")
WL = "vlc-wl"
BTN_LEFT = 0x110
KEYSYMS = {"F11": 0xffc8, "space": 0x20, "Escape": 0xff1b, "Return": 0xff0d, "Super_L": 0xffeb, "Up": 0xff52}


def bus_call(bus, name, path, iface, method, args, reply="()"):
    return bus.call_sync(name, path, iface, method, args, GLib.VariantType(reply),
                         Gio.DBusCallFlags.NONE, 10000, None)


def main():
    out = os.path.abspath(sys.argv[1])
    os.makedirs(out, exist_ok=True)
    env = dict(os.environ)
    env.pop("DISPLAY", None)
    prof = os.path.join(BUILD, "redesign-profile")
    env.update(XDG_CONFIG_HOME=f"{prof}/config", XDG_DATA_HOME=f"{prof}/data",
               XDG_CACHE_HOME=f"{prof}/cache", VLC_LIB_PATH=f"{BUILD}/modules",
               VLC_PLUGIN_PATH=f"{BUILD}/modules")

    shell = subprocess.Popen(["gnome-shell", "--headless", "--wayland", "--no-x11",
                              "--virtual-monitor", "1600x900", "--wayland-display", WL],
                             env=env, stdout=open(f"{out}/shell.log", "w"), stderr=subprocess.STDOUT)
    sock = os.path.join(env["XDG_RUNTIME_DIR"], WL)
    for _ in range(80):
        if os.path.exists(sock):
            break
        time.sleep(0.25)
    time.sleep(3)

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    rd_path = bus_call(bus, "org.gnome.Mutter.RemoteDesktop", "/org/gnome/Mutter/RemoteDesktop",
                       "org.gnome.Mutter.RemoteDesktop", "CreateSession", None, "(o)")[0]
    rd = Gio.DBusProxy.new_sync(bus, 0, None, "org.gnome.Mutter.RemoteDesktop", rd_path,
                                "org.gnome.Mutter.RemoteDesktop.Session", None)
    sid = rd.get_cached_property("SessionId").unpack()
    sc_path = bus_call(bus, "org.gnome.Mutter.ScreenCast", "/org/gnome/Mutter/ScreenCast",
                       "org.gnome.Mutter.ScreenCast", "CreateSession",
                       GLib.Variant("(a{sv})", ({"remote-desktop-session-id": GLib.Variant("s", sid)},)),
                       "(o)")[0]
    stream_path = bus_call(bus, "org.gnome.Mutter.ScreenCast", sc_path,
                           "org.gnome.Mutter.ScreenCast.Session", "RecordMonitor",
                           GLib.Variant("(sa{sv})", ("", {"cursor-mode": GLib.Variant("u", 0)})), "(o)")[0]
    node = {}

    def on_signal(_conn, _sender, _path, _iface, signal, params):
        if signal == "PipeWireStreamAdded":
            node["id"] = params.unpack()[0]

    bus.signal_subscribe("org.gnome.Mutter.ScreenCast", "org.gnome.Mutter.ScreenCast.Stream",
                         "PipeWireStreamAdded", stream_path, None, 0, on_signal)
    rd.call_sync("Start", None, 0, 10000, None)
    ctx = GLib.MainContext.default()
    deadline = time.time() + 10
    while "id" not in node and time.time() < deadline:
        ctx.iteration(False)
        time.sleep(0.05)
    if "id" not in node:
        sys.exit("no PipeWire stream")

    def pump(seconds):
        end = time.time() + seconds
        while time.time() < end:
            ctx.iteration(False)
            time.sleep(0.02)

    # the virtual pointer starts in the top-left hot corner, which toggles the Overview
    rd.call_sync("NotifyPointerMotionAbsolute", GLib.Variant("(sdd)", (stream_path, 800.0, 450.0)), 0, 5000, None)
    pump(0.5)

    def key(sym, down):
        rd.call_sync("NotifyKeyboardKeysym", GLib.Variant("(ub)", (sym, down)), 0, 5000, None)

    vlc = None
    for step in sys.argv[2:]:
        verb, _, arg = step.partition(":")
        if verb == "vlc":
            args = [a for a in arg.split(",") if a]
            venv = dict(env, WAYLAND_DISPLAY=WL, QT_QPA_PLATFORM="wayland")
            # extra environment for VLC, e.g. WL_VLC_ENV="WAYLAND_DEBUG=1;QT_LOGGING_RULES=qt.qpa.*=true"
            for kv in filter(None, os.environ.get("WL_VLC_ENV", "").split(";")):
                k, _, v = kv.partition("=")
                venv[k] = v
            vlc = subprocess.Popen([f"{BUILD}/bin/vlc-static", "-vv", "-I", "qt", "--no-qt-privacy-ask",
                                    "--restore-playback-pos=0", *args], env=venv,
                                   stdout=open(f"{out}/vlc.log", "w"), stderr=subprocess.STDOUT)
            pump(12)
        elif verb == "max":
            key(KEYSYMS["Super_L"], True); key(KEYSYMS["Up"], True)
            key(KEYSYMS["Up"], False); key(KEYSYMS["Super_L"], False)
            pump(2)
        elif verb == "sleep":
            pump(float(arg))
        elif verb == "shot":
            subprocess.run(["gst-launch-1.0", "-q", "pipewiresrc", f"path={node['id']}", "num-buffers=1",
                            "!", "videoconvert", "!", "pngenc", "!", "filesink",
                            f"location={out}/{arg}.png"], check=True, timeout=20)
            print(f"saved {out}/{arg}.png")
        elif verb == "move":
            x, y = (float(v) for v in arg.split(","))
            rd.call_sync("NotifyPointerMotionAbsolute", GLib.Variant("(sdd)", (stream_path, x, y)), 0, 5000, None)
            pump(0.3)
        elif verb == "click":
            x, y = (float(v) for v in arg.split(","))
            rd.call_sync("NotifyPointerMotionAbsolute", GLib.Variant("(sdd)", (stream_path, x, y)), 0, 5000, None)
            pump(0.3)
            rd.call_sync("NotifyPointerButton", GLib.Variant("(ib)", (BTN_LEFT, True)), 0, 5000, None)
            rd.call_sync("NotifyPointerButton", GLib.Variant("(ib)", (BTN_LEFT, False)), 0, 5000, None)
            pump(0.3)
        elif verb == "key":
            sym = KEYSYMS.get(arg) or int(arg, 0)
            key(sym, True); key(sym, False)
            pump(0.3)
        else:
            sys.exit(f"unknown step {step}")

    if vlc:
        vlc.terminate()
        try:
            vlc.wait(5)
        except subprocess.TimeoutExpired:
            vlc.kill()
    shell.terminate()
    shell.wait(10)


if __name__ == "__main__":
    main()
