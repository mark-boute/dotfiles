{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.latex;

  tex = pkgs.texliveSmall.withPackages (
    ps: [
      ps.collection-mathscience
      ps.mathtools
      ps.latexmk
      ps.hyperref
    ]
  );

  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.latex = {
    enable = mkEnableOption "latex";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tex
      ltex-ls-plus
    ];
  };
}
