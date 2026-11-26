{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.latex = {
    home-manager.sharedModules = [ homeManager.latex ];
  };

  flake.modules.homeManager.latex =
    { pkgs, ... }:
    let
      tex = pkgs.texliveSmall.withPackages (ps: [
        ps.collection-mathscience
        ps.mathtools
        ps.latexmk
        ps.hyperref
      ]);
    in
    {
      home.packages = [
        tex
        pkgs.ltex-ls-plus
      ];
    };
}
