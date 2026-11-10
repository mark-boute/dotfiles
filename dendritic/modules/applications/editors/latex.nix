{ config, ... }:
{
  flake.modules.nixos.latex = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.latex ];
  };

  flake.modules.homeManager.latex = { pkgs, ... }:
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
