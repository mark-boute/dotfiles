{ config, lib, pkgs, ... }:
let
  cfg = config.modules.latex;

  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full
      dvisvgm dvipng # for preview and export as html

      # for multifile projects
      standalone import

      wrapfig amsmath ulem hyperref capt-of accsupp;
      #(setq org-latex-compiler "lualatex")
      #(setq org-preview-latex-default-process dvisvgm)
  });

  inherit (lib) mkEnableOption mkIf;
in
{ # home-manager

  options.modules.latex = {
    enable = mkEnableOption "latex";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tex
      ltex-ls # this is outdated, use ltex-ls-plus instead. Download from https://github.com/ltex-plus/vscode-ltex-plus

      jdk23
    ];
  };
}
