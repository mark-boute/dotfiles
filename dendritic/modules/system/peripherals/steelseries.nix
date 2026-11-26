{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # Arctis 7: the auto-off timer lives in the headset. 0 (never) while in use,
  # 1 min at shutdown/suspend and 5 min after the screen lock.
  flake.modules.nixos.arctis = { pkgs, ... }: {
    home-manager.sharedModules = [ homeManager.arctis ];

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
        # "-": exits 1 when the dongle isn't plugged in, which would fail nixos-rebuild switch
        ExecStart = "-${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 0";
      };
    };

    # re-arm the timer before the dongle loses power; otherwise the headset
    # stays on searching after shutdown
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
  };

  flake.modules.homeManager.arctis = { pkgs, ... }: {
    # 5 minutes after the lock (1 min of silence)
    services.hypridle.settings.listener = [
      {
        timeout = 900;
        on-timeout = "${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 1";
        on-resume = "${pkgs.headsetcontrol}/bin/headsetcontrol --inactive-time 0";
      }
    ];
  };

  # Rival 600 / Apex 3 RGB. Not services.hardware.openrgb: that loads i2c-dev and
  # probes every i2c bus as root, including the dGPU's, which wakes it.
  flake.modules.nixos.openrgb =
    { pkgs, ... }:
    let
      profile = "default"; # saved from the GUI in ~/.config/OpenRGB
    in
    {
      environment.systemPackages = [ pkgs.openrgb ];
      services.udev.packages = [ pkgs.openrgb ];

      systemd.user.services.openrgb-profile = {
        description = "Apply OpenRGB profile";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        unitConfig.ConditionPathExists = "%h/.config/OpenRGB/${profile}.orp";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.openrgb}/bin/openrgb --noautoconnect --profile ${profile}";
        };
      };
    };
}
