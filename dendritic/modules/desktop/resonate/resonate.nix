{ config, ... }:
{
  flake.modules.nixos.resonate = { pkgs, ... }: {
    imports = [ config.flake.modules.nixos.self-update ];

    home-manager.sharedModules = [ config.flake.modules.homeManager.resonate ];

    environment.systemPackages = [ pkgs.quickshell ];
  };

  flake.modules.homeManager.resonate = { config, osConfig, lib, pkgs, ... }:
  let
    # Wraps shell/scripts/lights_ctl.py (a plain, directly-runnable/testable Python
    # file) with a Python interpreter that has tinytuya on its PYTHONPATH. See
    # services/LightsService.qml, which shells out to `lights-ctl` by name.
    # One binary for every light in the house — Tuya bulbs (tinytuya) and WiZ (stdlib UDP).
    lightsCtl = pkgs.writers.writePython3Bin "lights-ctl" {
      libraries = [ pkgs.python3Packages.tinytuya ];
      # writePython3Bin flake8-checks the script at build time; only silencing
      # line-length (79 cols is unworkably tight with descriptive names).
      flakeIgnore = [ "E501" ];
    } (builtins.readFile ./shell/scripts/lights_ctl.py);
  in
  {
    home.packages = with pkgs; [
      hyprtoolkit
      lightsCtl
      cliphist     # clipboard history — ClipboardService + the launcher's clipboard page
      wl-clipboard # wl-paste --watch feeds cliphist; wl-copy re-copies a pick
    ] ++ catppuccin-cursors.all; # every flavor×accent cursor theme, so ThemeService
      # (services/ThemeService.qml) can `hyprctl setcursor` to whichever one
      # matches the live theme picker. All sourced from nixpkgs specifically
      # (see home.pointerCursor below) — the catppuccin module's own
      # `cursors.enable` pulls its *own* vendored/pinned catppuccin-cursors
      # build, and mixing that with nixpkgs's build of the same theme name
      # is a real conflict for buildEnv.

    # Bypasses the catppuccin module's own `cursors.enable` (see above) so
    # there's only ever one catppuccin-cursors source in play.
    home.pointerCursor = lib.mkForce {
      enable = true;
      name = "catppuccin-macchiato-rosewater-cursors";
      package = pkgs.catppuccin-cursors.macchiatoRosewater;
      size = 24;
      hyprcursor = {
        enable = true;
        size = 24;
      };
      gtk.enable = true;
    };

    # Clipboard history daemon: cliphist stores every wl-clipboard change; the
    # launcher's clipboard page reads/decodes/re-copies from it.
    systemd.user.services.cliphist = {
      Unit = {
        Description = "clipboard history (cliphist)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
      };
    };

    catppuccin = lib.mkForce {
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

    # Hand-provisioned (chmod 600), not nix-managed:
    #   ~/.config/resonate/checklist-token     — ControlPanel checklist bearer token
    #   ~/.config/resonate/lights-devices.json — Lights app device list (tinytuya wizard output + IPs)

    programs.kitty.settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      window_padding_width = 10;
      background_opacity = "0.7";
      background_blur = 50;
    };

    # Only this shell's own subdirectory under ~/.config/quickshell, so other
    # quickshell configs can live alongside it.
    xdg.configFile."quickshell/resonate".source = config.lib.file.mkOutOfStoreSymlink (osConfig.my.live ./shell);

    xdg.configFile."hypr/qs-config.lua".text = ''
      return "resonate"
    '';
  };
}
