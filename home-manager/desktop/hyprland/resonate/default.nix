{ config, lib, pkgs, ... }:

let
  cfg = config.modules.hyprland.resonate;
  inherit (lib) mkEnableOption mkIf mkForce;

  # Wraps scripts/lights_ctl.py (a plain, directly-runnable/testable Python
  # file — kept as a real file rather than a Nix string) with a Python
  # interpreter that has tinytuya on its PYTHONPATH. See
  # services/LightsService.qml, which shells out to the resulting `lights-ctl`
  # by name (no absolute path, no PATH-shadowing risk). One binary for every
  # light in the house — Tuya bulbs (tinytuya) and WiZ devices (stdlib UDP).
  lightsCtl = pkgs.writers.writePython3Bin "lights-ctl" {
    libraries = [ pkgs.python3Packages.tinytuya ];
    # writePython3Bin flake8-checks the script at build time; only silencing
    # line-length (79 cols is unworkably tight with descriptive names).
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./scripts/lights_ctl.py);
in
{
  options.modules.hyprland.resonate = {
    enable = mkEnableOption "Enable the Resonate quickshell system";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      hyprtoolkit
      hyprlauncher
      lightsCtl
    ];

    catppuccin = mkForce {
      enable = true;
      flavor = "macchiato";
      accent = "rosewater";
      kitty = {
        enable = true;
        flavor = "macchiato";
      };
    };

    programs.quickshell = {
      enable = true;
      # No systemd unit: home-manager's generates a bare `quickshell` with no
      # `-c resonate`, which just crash-loops looking for a "default" config.
      # resonate is launched by Hyprland instead (hypr/exec.lua → `qs -c resonate`).
      systemd.enable = false;
    };

    # The ControlPanel's checklist section reads a bearer token (server-side
    # NUXT_CHECKLIST_LOCAL_TOKEN) from ~/.config/resonate/checklist-token — see
    # services/ChecklistService.qml / Config.qml. That file is managed by hand
    # (chmod 600), not by nix, so it's not wired here. To move it into sops
    # later: add a `checklist-token` key to secrets/mark/mark-secrets.yaml and
    #   sops.secrets."checklist-token" = { };
    #   xdg.configFile."resonate/checklist-token".source =
    #     config.lib.file.mkOutOfStoreSymlink config.sops.secrets."checklist-token".path;

    # The Lights app reads its device list (WOOX/Tuya bulb local_keys, WiZ
    # device IPs) from ~/.config/resonate/lights-devices.json — see
    # services/LightsService.qml / Config.qml. Tuya entries are tinytuya's own
    # `wizard` output (a one-time Tuya IoT Platform key fetch) plus an "ip";
    # WiZ entries need no key. Hand-provisioned (chmod 600), not sops, not
    # committed, absent → the Lights drawer tile just never appears.

    programs.kitty.settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      window_padding_width = 10;
      background_opacity = "0.7";
      background_blur = 50;
    };

    # Symlink just this shell's own subdirectory under ~/.config/quickshell,
    # so it can live alongside other quickshell configs (e.g. cappuccino)
    # without either fighting over the whole ~/.config/quickshell symlink.
    xdg.configFile."quickshell/resonate".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/home-manager/desktop/hyprland/resonate";

    xdg.configFile."hypr/qs-config.lua".text = ''
      return "resonate"
    '';
  };
}
