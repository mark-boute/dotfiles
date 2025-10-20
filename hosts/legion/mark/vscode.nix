{ pkgs, ... }:
{
  config.programs.vscode = {
      enable = true;
      profiles.default = {
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

          vue.volar
          hediet.vscode-drawio
        ];
        userSettings = {
          # editor settings
          "editor.semanticHighlighting.enabled" = true;
          "editor.fontFamily" = "JetBrainsMono NF";
          "editor.fontSize" = 14;
          "editor.fontLigatures" = true;
          "editor.cursorBlinking" = "smooth";

          "editor.minimap.autohide" = "mouseover";
          "editor.minimap.maxColumn" = 50;
          "editor.minimap.renderCharacters" = false;
          "editor.minimap.scale" = 2;

          "window.titleBarStyle" = "custom";
          "window.menuBarVisibility" = "visible";

          "github.copilot.enable" = {"*" = true;};
          "git.autofetch" = true;

          # theme settings
          "catppuccin.accentColor" = "rosewater";
          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin-macchiato";

          # nix
          "nix.formatterPath" = "nixfmt";
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
          "nix.serverSettings" = {
            "nixd.formatting.command" = ["nixfmt"];
            "options" = {
              "nixos.expr" = "(builtins.getFlake \"/home/mark/dotfiles/flake.nix\").nixosConfigurations.legion.options";
              "home-manager.expr" = "(builtins.getFlake \"/home/mark/dotfiles/flake.nix\").homeConfigurations.mark.options";
            };
          };

          # java settings
          "java.jdt.ls.java.home" = "${pkgs.jdk21}";

          # pdf viewer
          "latex-workshop.view.pdf.zoom" = "page-width";
          "latex-workshop.latex.outDir" = "%DIR%/out";
          "latex-workshop.view.pdf.color.dark.backgroundColor" = "#1e2030";
          "latex-workshop.view.pdf.color.dark.pageBorderColor" = "#181926";
          "latex-workshop.view.pdf.color.dark.pageColorsBackground" = "#24273a";
          "latex-workshop.view.pdf.color.dark.pageColorsForeground" = "#cad3f5";

          # markdown preview
          "markdown-preview-enhanced.previewTheme" = "none.css";
          "markdown-preview-enhanced.codeBlockTheme" = "atom-material.css";

          # vscode-drawio
          "hediet.vscode-drawio.appearance" = "automatic";
        };
      };
    };
}