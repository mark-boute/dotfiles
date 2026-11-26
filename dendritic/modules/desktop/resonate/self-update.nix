{
  # nixos-switch-to@<escaped store path>.service: what `nixos-rebuild switch` does
  # after building. resonate's update tile (shell/scripts/system_update.sh) builds
  # unprivileged and starts this unit, which goes through polkit (password prompt).
  flake.modules.nixos.self-update =
    { pkgs, config, ... }:
    let
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
    in
    {
      systemd.services."nixos-switch-to@" = {
        description = "Switch to NixOS system %f";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${switchTo} %f";
        };
      };
    };
}
