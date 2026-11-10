{ inputs, ... }:
{
  flake.modules.nixos.claude-desktop = { config, pkgs, ... }: {
    imports = [ inputs.claude-desktop.nixosModules.default ];

    programs.claude-desktop = {
      enable = true;
      cowork.users = [ config.my.user.name ];
      # shell wrapper so upstream's ''${VAR:+...} flags expand; keyring isn't autodetected on Hyprland
      package = (pkgs.callPackage "${inputs.claude-desktop}/package.nix" { }).overrideAttrs (old: rec {
        # upstream flake lags the apt repo; the bundled Claude Code version is pinned per app release
        version = "4.23118.1";
        src = pkgs.fetchurl {
          url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
          sha256 = "b09ccdd72b38916c9637d48548db70e77c425eb2e09bb467465409d2ff9d287a";
        };
        postFixup = builtins.replaceStrings
          [ "makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop" ]
          [ "makeShellWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop --add-flags --password-store=gnome-libsecret" ]
          old.postFixup;
      });
    };
  };
}
