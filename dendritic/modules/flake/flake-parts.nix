{ inputs, ... }:
{
  # flake.modules.<class>.<name>: the aspect registry every other file adds to
  imports = [ inputs.flake-parts.flakeModules.modules ];

  systems = [ "x86_64-linux" ];

  # exposes .debug.options so nixd can show flake-parts option docs on hover
  debug = true;

  # `nix fmt` formats every .nix file with nixfmt
  perSystem = { pkgs, ... }: {
    # rooted at the nearest flake.lock, so it stays inside this flake
    formatter = pkgs.nixfmt-tree.override { settings.tree-root-file = "flake.lock"; };
  };
}
