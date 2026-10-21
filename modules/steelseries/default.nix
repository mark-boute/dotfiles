{ pkgs, lib, config, ... }:

let
  cfg = config.modules.steelseries;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
in {

  options.modules.steelseries = {

    headsetAlwaysOn = mkEnableOption "disabling the Arctis 7 auto-off timer whenever it connects";

    rgb = mkEnableOption "OpenRGB for the Rival 600 / Apex 3 (USB only, no i2c probing)";

    rgbProfile = mkOption {
      default = "default";
      type = types.str;
      description = "OpenRGB profile (saved from the GUI in ~/.config/OpenRGB) applied at login.";
    };
  };

  config = mkMerge [
    ( mkIf cfg.headsetAlwaysOn {
      environment.systemPackages = [ pkgs.headsetcontrol ];
      services.udev.packages = [ pkgs.headsetcontrol ];

      # re-run on every reconnect: headset power-on only flips the dongle's wireless_status
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12ad", RUN+="${pkgs.systemd}/bin/systemctl --no-block start arctis-always-on.service"
        ACTION=="change", SUBSYSTEM=="usb", ATTR{wireless_status}=="connected", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12ad", RUN+="${pkgs.systemd}/bin/systemctl --no-block start arctis-always-on.service"
      '';

      systemd.services.arctis-always-on = {
        description = "Disable SteelSeries Arctis 7 inactivity shutdown";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
          ExecStart = "${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 0";
        };
      };

      # the timer lives in the headset, so re-arm it before the dongle loses power;
      # otherwise the headset stays on searching after shutdown
      systemd.services.arctis-auto-off-on-shutdown = {
        description = "Re-enable SteelSeries Arctis 7 auto-off at shutdown";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
          ExecStop = "-${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 1";
        };
      };

      powerManagement.powerDownCommands = ''
        ${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 1 || true
      '';
      powerManagement.resumeCommands = ''
        ${pkgs.systemd}/bin/systemctl --no-block start arctis-always-on.service
      '';
    })

    ( mkIf cfg.rgb {
      # not services.hardware.openrgb: that loads i2c-dev and probes every i2c bus as root,
      # including the dGPU's, which wakes it
      environment.systemPackages = [ pkgs.openrgb ];
      services.udev.packages = [ pkgs.openrgb ];

      systemd.user.services.openrgb-profile = {
        description = "Apply OpenRGB profile";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        unitConfig.ConditionPathExists = "%h/.config/OpenRGB/${cfg.rgbProfile}.orp";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.openrgb}/bin/openrgb --noautoconnect --profile ${cfg.rgbProfile}";
        };
      };
    })
  ];
}
