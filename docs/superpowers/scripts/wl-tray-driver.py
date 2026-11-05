#!/usr/bin/python3 -I
"""Exercise VLC's tray icon by acting as the StatusNotifier host on a private D-Bus session.

Start VLC minimized under wl-drive.py in the same session; this exits non-zero on a wrong
menu label or a missing item:

    dbus-run-session -- sh -c "docs/superpowers/scripts/wl-tray-driver.py [--quit-hidden] & \
        docs/superpowers/scripts/wl-drive.py OUT vlc:--qt-start-minimized shot:hidden exit:90; wait"

Default sequence, about 15s apart: Activate shows, Activate hides, menu Show, menu Quit.
With --quit-hidden: menu Quit without ever showing the window.
wl-drive.py prints the exit code; compare its shots at matching times for what the window did.
"""
import sys
import threading
import time

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

XML = """<node><interface name='org.kde.StatusNotifierWatcher'>
<method name='RegisterStatusNotifierItem'><arg type='s' direction='in'/></method>
<method name='RegisterStatusNotifierHost'><arg type='s' direction='in'/></method>
<property name='IsStatusNotifierHostRegistered' type='b' access='read'/>
<property name='ProtocolVersion' type='i' access='read'/>
<property name='RegisteredStatusNotifierItems' type='as' access='read'/>
</interface></node>"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
items = []


def on_call(_conn, _sender, _path, _iface, method, params, invocation):
    if method == "RegisterStatusNotifierItem":
        items.append(params.unpack()[0])
    invocation.return_value(None)


def on_prop(_conn, _sender, _path, _iface, prop):
    return {"IsStatusNotifierHostRegistered": GLib.Variant("b", True),
            "ProtocolVersion": GLib.Variant("i", 0),
            "RegisteredStatusNotifierItems": GLib.Variant("as", items)}[prop]


bus.register_object("/StatusNotifierWatcher", Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0],
                    on_call, on_prop, None)
Gio.bus_own_name_on_connection(bus, "org.kde.StatusNotifierWatcher", 0, None, None)
threading.Thread(target=GLib.MainLoop().run, daemon=True).start()

deadline = time.time() + 90
while not items and time.time() < deadline:
    time.sleep(0.2)
if not items:
    sys.exit("FAIL: no tray item registered")
start = time.time()
item = items[0]


def call(path, iface, method, args, reply="()"):
    return bus.call_sync(item, path, iface, method, args, GLib.VariantType(reply), 0, 8000, None)


def until(seconds):
    time.sleep(max(0, start + seconds - time.time()))


def activate():
    print("activate", flush=True)
    call("/StatusNotifierItem", "org.kde.StatusNotifierItem", "Activate", GLib.Variant("(ii)", (0, 0)))


def menu_items():
    menu = call("/StatusNotifierItem", "org.freedesktop.DBus.Properties", "Get",
                GLib.Variant("(ss)", ("org.kde.StatusNotifierItem", "Menu")), "(v)")[0]
    _rev, (_id, _props, kids) = call(menu, "com.canonical.dbusmenu", "GetLayout",
                                     GLib.Variant("(iias)", (0, -1, [])), "(u(ia{sv}av))").unpack()
    return menu, {k[0]: k[1].get("label", "").replace("_", "").lower() for k in kids}


def expect(word):
    labels = menu_items()[1].values()
    print("first entry:", next(iter(labels)), flush=True)
    if not next(iter(labels)).startswith(word):
        sys.exit(f"FAIL: expected the first menu entry to start with '{word}'")


def click(word):
    menu, labels = menu_items()
    entry = next((i for i, label in labels.items() if label.startswith(word)), None)
    if entry is None:
        sys.exit(f"FAIL: no menu entry '{word}' in {list(labels.values())}")
    print("click", labels[entry], flush=True)
    call(menu, "com.canonical.dbusmenu", "Event", GLib.Variant("(isvu)", (entry, "clicked", GLib.Variant("i", 0), 0)))


until(13)
expect("show")
if "--quit-hidden" in sys.argv:
    click("quit")
else:
    activate()
    until(25); expect("hide"); activate()
    until(38); expect("show"); click("show")
    until(50); expect("hide"); click("quit")
print("PASS: tray driver finished", flush=True)
