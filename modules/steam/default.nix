{ pkgs, lib, config, ... }:

let 
  cfg = config.modules.steam;
  inherit (lib) mkEnableOption mkIf mkMerge optionals types mkOption;
in {

  options.modules.steam = { 

    enable = mkEnableOption "steam"; 

    setgamemode = mkOption {
      default = false;
      type = types.bool;
      description = "Enable gamemode. NOTE! This will override the gamemode setting in the optimus-prime module.";
    };

    addmangohud = mkOption {
      default = false;
      type = types.bool;
      description = "Add mangohud to the systemPackages.";
    };

    addprotonup = mkOption {
      default = false;
      type = types.bool;
      description = "Add protonup to the systemPackages.";
    };

    controllerpad = mkOption {
      default = false;
      type = types.bool;
      description = "Expose the 2026 Steam Controller as an Xbox 360 pad to non-Steam games while Steam is closed.";
    };
  };

  config = mkMerge [
    ( mkIf cfg.enable {

      programs.steam.enable = true;
      programs.steam.gamescopeSession.enable = true;

      environment.systemPackages = with pkgs; [ 

      ] ++ optionals cfg.addmangohud [ mangohud ]
        ++ optionals cfg.addprotonup [ protonup-ng ];

      # inside Steam's FHS env too, so `mangohud %command%` and MANGOHUD=1 find the Vulkan layer
      programs.steam.extraPackages = optionals cfg.addmangohud [ pkgs.mangohud ];

    })
    ( mkIf (cfg.enable && cfg.controllerpad) {
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
    })
    # seperate module for gamemode to allow for safe override
    ( mkIf (cfg.enable && cfg.setgamemode) {
      programs.gamemode.enable = true;
    })
    # seperate module for protonup session variable to allow for safe override
    ( mkIf (cfg.enable && cfg.addprotonup) {
      environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATH = "\${HOME}/.steam/root/compatibilitytools.d";
    })
  ];
}