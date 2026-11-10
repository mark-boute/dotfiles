{
  # Expose the 2026 Steam Controller as an Xbox 360 pad to non-Steam games while Steam is closed.
  flake.modules.nixos.steam-controller-pad = { pkgs, ... }: {
    hardware.uinput.enable = true;

    systemd.services.steam-controller-pad = {
      description = "Steam Controller (2026) to Xbox 360 pad bridge";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3.withPackages (ps: [ ps.evdev ])}/bin/python3 -u ${./steam-controller-pad.py}";
        Restart = "always";
        RestartSec = 2;
        # root without capabilities: Steam's uaccess ACL on /dev/uinput blanks group access
        CapabilityBoundingSet = "";
        DeviceAllow = [ "char-input rw" "/dev/uinput rw" "char-usb rw" ];
        DevicePolicy = "closed";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateNetwork = true;
        NoNewPrivileges = true;
      };
    };

    # Games should only see the bridge's Xbox pad: the raw hid-steam nodes are
    # grabbed by the bridge (silent to everyone else) yet enumerate as pad #0.
    # Sorts between 70-uaccess and 73-seat-late, so dropping the tag skips the ACL.
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/72-steam-controller-pad.rules" ''
        SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Wireless Steam Controller|Steam Controller|Steam Controller Motion Sensors", TAG-="uaccess", MODE="0600"
      '')
    ];

    # SDL's HIDAPI driver would open the hidraw node, which hid-steam treats as
    # a Steam client and stops the evdev events the bridge reads.
    environment.sessionVariables.SDL_JOYSTICK_HIDAPI_STEAM = "0";
    # flatpaks don't inherit sessionVariables
    services.flatpak.overrides.settings."org.vinegarhq.Sober".Environment.SDL_JOYSTICK_HIDAPI_STEAM = "0";
  };
}
