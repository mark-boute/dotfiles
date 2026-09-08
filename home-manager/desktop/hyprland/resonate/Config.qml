pragma Singleton

import Quickshell
import QtQuick

// Machine-local, non-visual configuration — the stuff that would otherwise be
// hard-coded across widgets/services. Kept separate from Theme.qml (which is
// purely appearance) and from anything secret: the checklist bearer token is
// read at runtime from a sops-managed file, never committed here.
Singleton {
  id: config;

  // --- Checklist widget (markboute.nl) ---
  // All three route to the same container/DB; the list is just fallback order
  // for whichever network path is currently up (public → LAN → local port).
  // ChecklistService tries them in order and sticks with the first that answers.
  // RESONATE_CHECKLIST_URL overrides the whole list with a single URL.
  readonly property var checklistUrls: {
    var o = Quickshell.env("RESONATE_CHECKLIST_URL");
    return o ? [o] : [
      // "https://markboute.nl",  // add once the public host is configured
      "https://home.markboute.nl",
      "http://localhost:3000",
    ];
  }

  // A file containing just the bearer token (server-side NUXT_CHECKLIST_LOCAL_TOKEN).
  // Provisioned by home-manager/desktop/hyprland/resonate/default.nix via
  // sops-nix. Absent/empty → the checklist panel shows a "not configured" note
  // instead of erroring. Override the location with RESONATE_CHECKLIST_TOKEN_FILE.
  readonly property string checklistTokenFile:
    Quickshell.env("RESONATE_CHECKLIST_TOKEN_FILE")
    || (Quickshell.env("HOME") + "/.config/resonate/checklist-token");

  // --- Lights (WOOX/Tuya bulbs + WiZ devices, see services/LightsService.qml) ---
  // A JSON list of device entries: Tuya bulbs (tinytuya wizard output + "ip",
  // contains the local_key secret) and WiZ devices (just "ip", no secret).
  // Hand-provisioned (chmod 600), not sops-managed, same treatment as
  // checklistTokenFile above. Absent/empty → the Lights drawer tile just never
  // becomes visible, no error shown. Override the location with
  // RESONATE_LIGHTS_DEVICES_FILE.
  readonly property string lightsDevicesFile:
    Quickshell.env("RESONATE_LIGHTS_DEVICES_FILE")
    || (Quickshell.env("HOME") + "/.config/resonate/lights-devices.json");
}
