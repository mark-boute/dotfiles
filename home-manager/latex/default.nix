{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.modules.latex;

  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-medium
      dvisvgm dvipng # for preview and export as html

      # for multifile projects

      wrapfig amsmath ulem hyperref capt-of;
      # (setq org-latex-compiler "lualatex")
      # (setq org-preview-latex-default-process dvisvgm)
  });
in
{ # home-manager

  options.modules.latex = {
    enable = mkEnableOption "latex";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      tex
      ltex-ls # this is outdated, use ltex-ls-plus instead. Download from https://github.com/ltex-plus/vscode-ltex-plus

      jdk22
    ];
  };
}