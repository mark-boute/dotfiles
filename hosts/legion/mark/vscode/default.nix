{ pkgs, lib, config, ... }:
{
  config = {
    home.packages = with pkgs; [
      vscode-extensions.github.copilot
      prettypst
      # jdt-language-server
    ];
  };

  config.programs.vscode = {
      enable = true;
      profiles.default = lib.mkForce {
        extensions = with pkgs.vscode-extensions; [
          github.copilot

          redhat.java
          vscjava.vscode-java-pack

          catppuccin.catppuccin-vsc
          # catppuccin.catppuccin-vsc-icons

          bierner.markdown-mermaid

          arrterian.nix-env-selector
          jnoortheen.nix-ide

          james-yu.latex-workshop
          tecosaur.latex-utilities

          myriad-dreamin.tinymist

          vue.volar
          hediet.vscode-drawio
        ];
      };
    };

  config.xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/hosts/legion/mark/vscode/settings.json";
}
