{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.modules.latex;

  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-basic
      dvisvgm dvipng # for preview and export as html
      wrapfig amsmath ulem hyperref capt-of;
      #(setq org-latex-compiler "lualatex")
      #(setq org-preview-latex-default-process 'dvisvgm)
  });
in
{ # home-manager

  options.modules.latex = {
    enable = mkEnableOption "latex";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tex
    ];
  };
}