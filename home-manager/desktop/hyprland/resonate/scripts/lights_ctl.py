"""Thin CLI wrapper behind resonate's LightsService.qml — one binary that
speaks to every kind of light in the house.

Packaged as the `lights-ctl` derivation (see default.nix's `lightsCtl`, a
writers.writePython3Bin wrapping this file with tinytuya on PYTHONPATH) — that
wrapper supplies its own shebang, so this file intentionally has none. For
manual/standalone testing, just run it as `python3 scripts/lights_ctl.py ...`
against a Python with tinytuya installed.

Reads a JSON list of device entries and either polls every device's status
concurrently, or sends one set-command to a single device. Each entry has a
`type` (default "tuya"):

  tuya  {"type","id","key","ip","name","version"}  — exactly tinytuya's own
        `devices.json` wizard output, plus an "ip" and optional "version".
  wiz   {"type","id","ip","name","caps"}           — a WiZ device on the LAN;
        no key/pairing, controlled over its open UDP :38899 JSON-RPC.

`caps` lists what the UI should expose for a device: a subset of
["power", "brightness", "temperature", "color"] ("temperature" = white
warmth). Absent → a sane per-type default (Tuya bulbs get all four; a WiZ entry
defaults to power+brightness — a socket should carry an explicit
"caps": ["power"]).

Every subcommand prints exactly one line of JSON to stdout and exits 0 on
success. On failure it prints a one-line message to stderr and exits non-zero
— LightsService.qml treats that the same way ChecklistService.qml treats a
failed PATCH: a soft, recoverable error, never a crash.

Connection is always local — no vendor cloud call is ever made here. Tuya
retries are capped low (see bulb_for() below) so a single offline bulb can't
stall a `status` poll for long; devices are queried concurrently for the same
reason.
"""

import argparse
import concurrent.futures
import json
import socket
import sys

try:
    import tinytuya
except ImportError:
    print("tinytuya is not installed — run this via the packaged lights-ctl, "
          "not a bare system python3", file=sys.stderr)
    sys.exit(2)

# Keep a single offline/slow bulb from blocking a status poll for long —
# BulbDevice's own defaults (connection_timeout=5, connection_retry_limit=5,
# connection_retry_delay=5) can take up to ~25s per device otherwise.
CONNECT_TIMEOUT = 3
RETRY_LIMIT = 1

WIZ_PORT = 38899
WIZ_TIMEOUT = 2.0

DEFAULT_CAPS = {
    "tuya": ["power", "brightness", "temperature", "color"],
    "wiz": ["power", "brightness"],
}


def load_devices(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    # tinytuya's wizard writes a bare list; tolerate a {"devices": [...]} shape too.
    if isinstance(data, dict):
        data = data.get("devices", [])
    return data


def dev_type(dev):
    return dev.get("type", "tuya")


def dev_caps(dev):
    return dev.get("caps") or DEFAULT_CAPS.get(dev_type(dev), ["power"])


def find_device(devices, device_id):
    for d in devices:
        if d["id"] == device_id:
            return d
    return None


# --- tuya ------------------------------------------------------------------

# Raw DPS indices for the "type B" (DPS 20-29) map every RGBCW Tuya bulb
# resonate is pointed at uses. We set these directly rather than via
# tinytuya's set_*_percentage helpers: those need a bulb_type that only
# auto-detects after an extra probe round trip, and pinning it by hand throws
# off the generic read path that otherwise works fine.
DP_MODE = "21"       # "white" | "colour"
DP_COLOURTEMP = "23"  # 0 (warmest) .. 1000 (coolest)


def bulb_for(dev):
    return tinytuya.BulbDevice(
        dev_id=dev["id"],
        address=dev.get("ip"),
        local_key=dev["key"],
        version=float(dev.get("version") or 3.3),
        connection_timeout=CONNECT_TIMEOUT,
        connection_retry_limit=RETRY_LIMIT,
    )


def read_tuya(dev, out):
    b = bulb_for(dev)
    state = b.state()
    if not isinstance(state, dict) or "Error" in state or state.get("is_on") is None:
        return out
    out["reachable"] = True
    out["on"] = bool(state.get("is_on"))
    try:
        out["brightness"] = round(b.get_brightness_percentage(state=state))
    except Exception:
        pass
    if "temperature" in out["caps"]:
        try:
            out["temperature"] = round(b.get_colourtemp_percentage(state=state))
        except Exception:
            pass
    try:
        r, g, bl = b.colour_rgb(state=state)
        out["rgb"] = [int(r), int(g), int(bl)]
    except Exception:
        pass
    return out


def set_tuya_power(dev, on):
    b = bulb_for(dev)
    return b.turn_on() if on else b.turn_off()


# Some Tuya/WOOX firmwares ignore a brightness/colour write while the bulb is
# off, so every setter powers it on first — but nowait=True, so that's a single
# fire-and-forget packet rather than a full extra round trip on every slider tick.
def set_tuya_brightness(dev, percent):
    b = bulb_for(dev)
    b.turn_on(nowait=True)
    return b.set_brightness_percentage(percent)


def set_tuya_temperature(dev, percent):
    b = bulb_for(dev)
    b.turn_on(nowait=True)
    b.set_value(DP_MODE, "white", nowait=True)
    scaled = int(round(max(0, min(100, percent)) / 100 * 1000))
    return b.set_value(DP_COLOURTEMP, scaled)


def set_tuya_color(dev, r, g, bl):
    b = bulb_for(dev)
    b.turn_on(nowait=True)
    return b.set_colour(r, g, bl)


# --- wiz -----------------------------------------------------------------

def wiz_rpc(ip, method, params=None):
    """One request/response against a WiZ device's local JSON-RPC socket.
    Raises on timeout or a malformed reply — callers treat that as offline."""
    msg = json.dumps({"method": method, "params": params or {}}).encode()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(WIZ_TIMEOUT)
    try:
        s.sendto(msg, (ip, WIZ_PORT))
        data, _ = s.recvfrom(2048)
    finally:
        s.close()
    reply = json.loads(data.decode())
    if "error" in reply:
        raise RuntimeError(reply["error"])
    return reply.get("result", {})


def read_wiz(dev, out):
    r = wiz_rpc(dev["ip"], "getPilot")
    if "state" not in r:
        return out
    out["reachable"] = True
    out["on"] = bool(r["state"])
    if "dimming" in r and "brightness" in out["caps"]:
        out["brightness"] = int(r["dimming"])
    if all(k in r for k in ("r", "g", "b")):
        out["rgb"] = [int(r["r"]), int(r["g"]), int(r["b"])]
    return out


def set_wiz_power(dev, on):
    wiz_rpc(dev["ip"], "setPilot", {"state": bool(on)})


def set_wiz_brightness(dev, percent):
    # WiZ dimming floors at 10; a 0 from the slider means "off", not "dim".
    if percent <= 0:
        wiz_rpc(dev["ip"], "setPilot", {"state": False})
    else:
        wiz_rpc(dev["ip"], "setPilot",
                {"state": True, "dimming": max(10, min(100, percent))})


# --- commands ----------------------------------------------------------

def read_one(dev):
    out = {
        "id": dev["id"],
        "name": dev.get("name", dev["id"]),
        "type": dev_type(dev),
        "caps": dev_caps(dev),
        "reachable": False,
    }
    try:
        if dev_type(dev) == "wiz":
            return read_wiz(dev, out)
        return read_tuya(dev, out)
    except Exception:
        return out


def cmd_status(args):
    devices = load_devices(args.file)
    if not devices:
        print(json.dumps({"reachable": False, "devices": []}))
        return 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, len(devices))) as pool:
        results = list(pool.map(read_one, devices))
    reachable = any(d["reachable"] for d in results)
    print(json.dumps({"reachable": reachable, "devices": results}))
    return 0


def _resolve(args):
    """(dev, error_code) — prints its own stderr message on failure."""
    devices = load_devices(args.file)
    dev = find_device(devices, args.device_id)
    if not dev:
        print("unknown device id: %s" % args.device_id, file=sys.stderr)
        return None
    return dev


def _tuya_result_ok(result):
    if isinstance(result, dict) and "Error" in result:
        print(result["Error"], file=sys.stderr)
        return False
    return True


def cmd_power(args):
    dev = _resolve(args)
    if not dev:
        return 1
    on = args.state == "on"
    if dev_type(dev) == "wiz":
        set_wiz_power(dev, on)
    elif not _tuya_result_ok(set_tuya_power(dev, on)):
        return 1
    print(json.dumps({"ok": True, "id": args.device_id}))
    return 0


def cmd_brightness(args):
    dev = _resolve(args)
    if not dev:
        return 1
    if dev_type(dev) == "wiz":
        set_wiz_brightness(dev, args.percent)
    elif not _tuya_result_ok(set_tuya_brightness(dev, args.percent)):
        return 1
    print(json.dumps({"ok": True, "id": args.device_id}))
    return 0


def cmd_temperature(args):
    dev = _resolve(args)
    if not dev:
        return 1
    if "temperature" not in dev_caps(dev):
        print("device has no white-temperature control", file=sys.stderr)
        return 1
    if not _tuya_result_ok(set_tuya_temperature(dev, args.percent)):
        return 1
    print(json.dumps({"ok": True, "id": args.device_id}))
    return 0


def cmd_color(args):
    dev = _resolve(args)
    if not dev:
        return 1
    if "color" not in dev_caps(dev):
        print("device has no color control", file=sys.stderr)
        return 1
    if not _tuya_result_ok(set_tuya_color(dev, args.r, args.g, args.b)):
        return 1
    print(json.dumps({"ok": True, "id": args.device_id}))
    return 0


def main():
    parser = argparse.ArgumentParser(prog="lights-ctl")
    sub = parser.add_subparsers(dest="cmd", required=True)

    def add_file_arg(p):
        p.add_argument("--file", required=True, help="path to the lights devices JSON file")

    p_status = sub.add_parser("status")
    add_file_arg(p_status)
    p_status.set_defaults(func=cmd_status)

    p_power = sub.add_parser("power")
    p_power.add_argument("device_id")
    p_power.add_argument("state", choices=["on", "off"])
    add_file_arg(p_power)
    p_power.set_defaults(func=cmd_power)

    p_brightness = sub.add_parser("brightness")
    p_brightness.add_argument("device_id")
    p_brightness.add_argument("percent", type=int)
    add_file_arg(p_brightness)
    p_brightness.set_defaults(func=cmd_brightness)

    p_temperature = sub.add_parser("temperature")
    p_temperature.add_argument("device_id")
    p_temperature.add_argument("percent", type=int, help="0 = warmest, 100 = coolest")
    add_file_arg(p_temperature)
    p_temperature.set_defaults(func=cmd_temperature)

    p_color = sub.add_parser("color")
    p_color.add_argument("device_id")
    p_color.add_argument("r", type=int)
    p_color.add_argument("g", type=int)
    p_color.add_argument("b", type=int)
    add_file_arg(p_color)
    p_color.set_defaults(func=cmd_color)

    args = parser.parse_args()
    try:
        sys.exit(args.func(args))
    except FileNotFoundError:
        print("devices file not found: %s" % args.file, file=sys.stderr)
        sys.exit(3)
    except Exception as e:  # last-resort guard — LightsService only wants a clean exit code
        print(str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
