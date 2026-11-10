#!/usr/bin/env python3
# Re-exposes the 2026 Steam Controller (kernel hid-steam evdev device) as a
# virtual Xbox 360 pad, so non-Steam games see a standard controller.
# The right trackpad becomes a touchpad, the left one a scroll wheel (as in lizard mode).

import asyncio
import fcntl
import glob
import os
import struct

import evdev
from evdev import AbsInfo, UInput
from evdev import ecodes as e
from evdev.uinput import UInputError

SOURCE_NAMES = {"Wireless Steam Controller", "Steam Controller"}
SCAN_INTERVAL = 2

# hid-steam follows BTN_NORTH/BTN_WEST (X=north), xpad puts X on the left
BUTTONS = {code: code for code in (
    e.BTN_A, e.BTN_B, e.BTN_TL, e.BTN_TR,
    e.BTN_SELECT, e.BTN_START, e.BTN_MODE, e.BTN_THUMBL, e.BTN_THUMBR,
)} | {e.BTN_X: e.BTN_Y, e.BTN_Y: e.BTN_X}
STICKS = {e.ABS_X, e.ABS_Y, e.ABS_RX, e.ABS_RY}
TRIGGERS = {e.ABS_HAT2Y: e.ABS_Z, e.ABS_HAT2X: e.ABS_RZ}
DPAD = {
    e.BTN_DPAD_LEFT: (e.ABS_HAT0X, -1),
    e.BTN_DPAD_RIGHT: (e.ABS_HAT0X, 1),
    e.BTN_DPAD_UP: (e.ABS_HAT0Y, -1),
    e.BTN_DPAD_DOWN: (e.ABS_HAT0Y, 1),
}
PAD_AXES = {
    e.ABS_HAT0X: ("left", 0), e.ABS_HAT0Y: ("left", 1),
    e.ABS_HAT1X: ("right", 0), e.ABS_HAT1Y: ("right", 1),
}

PAD_MAX = 32767
PAD_RES = 1638  # units/mm, matches hid-steam
PAD_Y_UP = True  # raw pad Y grows upwards
SCROLL_UNITS_PER_NOTCH = 3000
SCROLL_NATURAL = True  # content follows the thumb, like Steam's lizard mode
CLICK_PULSE_US = 400  # same tick hid-steam uses for its mode-switch feedback

XBOX_CAPS = {
    e.EV_KEY: sorted(BUTTONS.values()),
    e.EV_ABS: [
        (e.ABS_X, AbsInfo(0, -32768, 32767, 16, 128, 0)),
        (e.ABS_Y, AbsInfo(0, -32768, 32767, 16, 128, 0)),
        (e.ABS_RX, AbsInfo(0, -32768, 32767, 16, 128, 0)),
        (e.ABS_RY, AbsInfo(0, -32768, 32767, 16, 128, 0)),
        (e.ABS_Z, AbsInfo(0, 0, 255, 0, 0, 0)),
        (e.ABS_RZ, AbsInfo(0, 0, 255, 0, 0, 0)),
        (e.ABS_HAT0X, AbsInfo(0, -1, 1, 0, 0, 0)),
        (e.ABS_HAT0Y, AbsInfo(0, -1, 1, 0, 0, 0)),
    ],
}

_pad_abs = AbsInfo(0, 0, 2 * PAD_MAX, 0, 0, PAD_RES)
TOUCHPAD_CAPS = {
    e.EV_KEY: [e.BTN_LEFT, e.BTN_TOUCH, e.BTN_TOOL_FINGER],
    e.EV_ABS: [
        (e.ABS_X, _pad_abs),
        (e.ABS_Y, _pad_abs),
        (e.ABS_MT_SLOT, AbsInfo(0, 0, 0, 0, 0, 0)),
        (e.ABS_MT_TRACKING_ID, AbsInfo(0, 0, 65535, 0, 0, 0)),
        (e.ABS_MT_POSITION_X, _pad_abs),
        (e.ABS_MT_POSITION_Y, _pad_abs),
    ],
}

MOUSE_CAPS = {
    e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
    e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL,
               e.REL_WHEEL_HI_RES, e.REL_HWHEEL_HI_RES],
}

active = {}


def steam_running():
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "steam":
                    return True
        except OSError:
            pass
    return False


def is_source(dev):
    if dev.info.vendor != 0x28DE or dev.name not in SOURCE_NAMES:
        return False
    keys = dev.capabilities().get(e.EV_KEY, [])
    return e.BTN_GRIPL2 in keys


class Touchpad:
    def __init__(self):
        self.dev = UInput(TOUCHPAD_CAPS, name="Steam Controller Touchpad",
                          vendor=0x28DE, product=0x1304, bustype=e.BUS_USB,
                          input_props=[e.INPUT_PROP_POINTER, e.INPUT_PROP_BUTTONPAD])
        self.touching = False
        self.tracking_id = 0

    def update(self, x, y, touched):
        dev = self.dev
        if touched:
            px = x + PAD_MAX
            py = (PAD_MAX - y) if PAD_Y_UP else (y + PAD_MAX)
            dev.write(e.EV_ABS, e.ABS_MT_SLOT, 0)
            if not self.touching:
                self.tracking_id = (self.tracking_id + 1) % 65536
                dev.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, self.tracking_id)
            dev.write(e.EV_ABS, e.ABS_MT_POSITION_X, px)
            dev.write(e.EV_ABS, e.ABS_MT_POSITION_Y, py)
            dev.write(e.EV_ABS, e.ABS_X, px)
            dev.write(e.EV_ABS, e.ABS_Y, py)
            if not self.touching:
                dev.write(e.EV_KEY, e.BTN_TOUCH, 1)
                dev.write(e.EV_KEY, e.BTN_TOOL_FINGER, 1)
        elif self.touching:
            dev.write(e.EV_ABS, e.ABS_MT_SLOT, 0)
            dev.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, -1)
            dev.write(e.EV_KEY, e.BTN_TOUCH, 0)
            dev.write(e.EV_KEY, e.BTN_TOOL_FINGER, 0)
        self.touching = touched

    def click(self, value):
        self.dev.write(e.EV_KEY, e.BTN_LEFT, value)

    def syn(self):
        self.dev.syn()

    def close(self):
        self.dev.close()


class ScrollPad:
    def __init__(self):
        self.dev = UInput(MOUSE_CAPS, name="Steam Controller Scroll Pad",
                          vendor=0x28DE, product=0x1304, bustype=e.BUS_USB)
        self.last = None
        self.acc = [0, 0]  # hi-res units (120 per notch) not yet sent as notches

    def update(self, x, y, touched):
        if not touched:
            self.last = None
            self.acc = [0, 0]
            return
        if self.last:
            dx = x - self.last[0]
            dy = (y - self.last[1]) if PAD_Y_UP else (self.last[1] - y)
            if SCROLL_NATURAL:
                dx, dy = -dx, -dy
            for i, (delta, lo, hi) in enumerate(((dy, e.REL_WHEEL, e.REL_WHEEL_HI_RES),
                                                 (dx, e.REL_HWHEEL, e.REL_HWHEEL_HI_RES))):
                hires = int(delta * 120 / SCROLL_UNITS_PER_NOTCH)
                if not hires:
                    continue
                self.dev.write(e.EV_REL, hi, hires)
                self.acc[i] += hires
                notches = int(self.acc[i] / 120)
                if notches:
                    self.dev.write(e.EV_REL, lo, notches)
                    self.acc[i] -= notches * 120
        self.last = (x, y)

    def click(self, value):
        self.dev.write(e.EV_KEY, e.BTN_RIGHT, value)

    def syn(self):
        self.dev.syn()

    def close(self):
        self.dev.close()


class Haptics:
    # Trackpad pulses (output report 0x81) via the receiver's hiddev node;
    # hidraw would count as a Steam client and stop hid-steam's evdev events.
    REPORT_OUTPUT = 2
    REPORT_PULSE = 0x81
    SIDE = {"right": 0, "left": 1}
    HIDIOCSUSAGES = (1 << 30) | ((28 + 1024 * 4) << 16) | (ord("H") << 8) | 0x14
    HIDIOCSREPORT = (1 << 30) | (12 << 16) | (ord("H") << 8) | 0x08

    def __init__(self, evdev_path):
        self.fd = None
        hid = os.path.realpath(f"/sys/class/input/{os.path.basename(evdev_path)}/device/device")
        for node in glob.glob(f"{hid}/../usbmisc/hiddev*"):
            try:
                self.fd = os.open(f"/dev/usb/{os.path.basename(node)}", os.O_RDWR)
                break
            except OSError as err:
                print(f"no haptics: {err}", flush=True)

    def pulse(self, side, on_us=CLICK_PULSE_US, off_us=0, count=1):
        if self.fd is None:
            return
        payload = struct.pack("<BHHH", self.SIDE[side], on_us, off_us, count)
        ref = struct.pack("<IIIIIiI", self.REPORT_OUTPUT, self.REPORT_PULSE,
                          0, 0, 0, 0, len(payload))
        values = struct.pack("<1024i", *payload, *[0] * (1024 - len(payload)))
        try:
            fcntl.ioctl(self.fd, self.HIDIOCSUSAGES, bytearray(ref + values))
            fcntl.ioctl(self.fd, self.HIDIOCSREPORT,
                        struct.pack("<III", self.REPORT_OUTPUT, self.REPORT_PULSE, 0))
        except OSError:
            pass

    def close(self):
        if self.fd is not None:
            os.close(self.fd)


async def bridge(path):
    src = evdev.InputDevice(path)
    devs = []
    haptics = None
    try:
        src.grab()
        pad = UInput(XBOX_CAPS, name="Microsoft X-Box 360 pad",
                     vendor=0x045E, product=0x028E, version=0x110,
                     bustype=e.BUS_USB)
        devs.append(pad)
        touchpad = Touchpad()
        devs.append(touchpad)
        scroll = ScrollPad()
        devs.append(scroll)
        pads = {"left": scroll, "right": touchpad}
        pad_pos = {"left": [0, 0], "right": [0, 0]}
        haptics = Haptics(path)
        clicked = {"left": 0, "right": 0}

        def pad_click(side, value):
            value = 1 if value else 0
            if value != clicked[side]:
                clicked[side] = value
                pads[side].click(value)
                haptics.pulse(side)

        trig_max = src.absinfo(e.ABS_HAT2X).max or 32767
        dpad = {code: 0 for code in DPAD}
        print(f"bridging {src.path} ({src.uniq}) -> {pad.device.path}", flush=True)

        def handle(etype, code, value):
            if etype == e.EV_KEY:
                if code in BUTTONS:
                    pad.write(e.EV_KEY, BUTTONS[code], value)
                elif code in DPAD:
                    dpad[code] = 1 if value else 0
                    axis = DPAD[code][0]
                    pad.write(e.EV_ABS, axis, sum(
                        sign * dpad[c] for c, (a, sign) in DPAD.items() if a == axis))
                elif code == e.BTN_THUMB2:
                    pad_click("right", value)
                elif code == e.BTN_THUMB:
                    pad_click("left", value)
            elif etype == e.EV_ABS:
                if code in STICKS:
                    pad.write(e.EV_ABS, code, value)
                elif code in TRIGGERS:
                    pad.write(e.EV_ABS, TRIGGERS[code],
                              min(255, value * 255 // trig_max))
                elif code in PAD_AXES:
                    side, i = PAD_AXES[code]
                    pad_pos[side][i] = value

        def report():
            # hid-steam reports an untouched pad as (0, 0)
            for side, (x, y) in pad_pos.items():
                pads[side].update(x, y, (x, y) != (0, 0))
            for d in devs:
                d.syn()

        def resync():
            # events were lost (SYN_DROPPED): rebuild state from the kernel
            pressed = set(src.active_keys())
            for code in [*BUTTONS, *DPAD, e.BTN_THUMB, e.BTN_THUMB2]:
                handle(e.EV_KEY, code, 1 if code in pressed else 0)
            for code in [*STICKS, *TRIGGERS, *PAD_AXES]:
                handle(e.EV_ABS, code, src.absinfo(code).value)
            report()

        dropped = False
        while True:
            for ev in await src.async_read():
                if ev.type == e.EV_SYN and ev.code == e.SYN_DROPPED:
                    dropped = True
                elif ev.type == e.EV_SYN and ev.code == e.SYN_REPORT:
                    if dropped:
                        dropped = False
                        resync()
                    else:
                        report()
                elif not dropped:
                    handle(ev.type, ev.code, ev.value)
    except (OSError, asyncio.CancelledError):
        pass
    except UInputError as err:
        print(f"cannot create virtual devices: {err}", flush=True)
    finally:
        for d in devs:
            d.close()
        if haptics:
            haptics.close()
        try:
            src.close()
        except OSError:
            pass
        active.pop(path, None)
        print(f"released {path}", flush=True)


async def main():
    while True:
        if steam_running():
            for task in list(active.values()):
                task.cancel()
        else:
            for path in evdev.list_devices():
                if path in active:
                    continue
                try:
                    dev = evdev.InputDevice(path)
                    match = is_source(dev)
                    dev.close()
                except OSError:
                    continue
                if match:
                    active[path] = asyncio.create_task(bridge(path))
        await asyncio.sleep(SCAN_INTERVAL)


asyncio.run(main())
