{ pkgs, lib, config, ... }:

let
  cfg = config.modules.system.selfUpdate;

  # what `nixos-rebuild switch` does after building; the build itself runs
  # unprivileged (resonate's scripts/system_update.sh)
  switchTo = pkgs.writeShellScript "nixos-switch-to" ''
    set -eu
    system="$1"
    case "$system" in
      /nix/store/*-nixos-system-*) ;;
      *) echo "not a NixOS system: $system" >&2; exit 1 ;;
    esac
    [ -x "$system/bin/switch-to-configuration" ] || { echo "no switch-to-configuration in $system" >&2; exit 1; }
    ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set "$system"
    exec "$system/bin/switch-to-configuration" switch
  '';
in {
  options.modules.system.selfUpdate.enable = lib.mkEnableOption
    "nixos-switch-to@<escaped store path>.service; starting it goes through polkit (password prompt)";

  config = lib.mkIf cfg.enable {
    systemd.services."nixos-switch-to@" = {
      description = "Switch to NixOS system %f";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${switchTo} %f";
      };
    };
  };
}
