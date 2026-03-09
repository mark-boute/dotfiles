{ pkgs, lib, ... }:
let 
  # Define Macchiato colors locally for reuse
  macchiato = {
    base = "#24273a";
    mantle = "#1e2030";
    crust = "#181926";
    text = "#cad3f5";
  };
in
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

          # file associations
          "workbench.editorAssociations" = {
            "*.pdf" = "latex-workshop-pdf-hook";
          };

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

          "qt-qml.qmlls.useQmlImportPathEnvVar" = true;

          # java settings
          "java.jdt.ls.java.home" = "${pkgs.jdk21}/lib/openjdk";
          "java.configuration.runtimes" = [
            {
              name = "JavaSE-21";
              path = "${pkgs.jdk21}/lib/openjdk";
              default = true;
            }
          ];

          # c# settings
          "omnisharp.useModernNet" = true;
          "omnisharp.dotnetPath" = "${pkgs.omnisharp-roslyn}/bin/omnisharp";
          "omnisharp.sdkPath" = "${pkgs.dotnet-sdk_10}/lib/dotnet";
	  
          # disable the stupid AI chat window
          "workbench.secondarySideBar.defaultVisibility" = "hidden";

          # typst
          "tinymist.exportPdf" = "onType";
          "tinymist.formatterMode" = "typstfmt";
          "tinymist.lint.enabled" = true;
          "tinymist.preview.background.enabled" = true;

          "[typst]" = {
            "editor.formatOnSave" = true;
          };

          # pdf viewer
          "latex-workshop.view.pdf.zoom" = "page-width";
          "latex-workshop.latex.outDir" = "%DIR%/out";
          "latex-workshop.view.pdf.color.dark.backgroundColor" = macchiato.mantle;
          "latex-workshop.view.pdf.color.dark.pageBorderColor" = macchiato.crust;
          "latex-workshop.view.pdf.color.dark.pageColorsBackground" = macchiato.base;
          "latex-workshop.view.pdf.color.dark.pageColorsForeground" = macchiato.text;

          # markdown preview
          "markdown-preview-enhanced.previewTheme" = "none.css";
          "markdown-preview-enhanced.codeBlockTheme" = "atom-material.css";

          # vscode-drawio
          "hediet.vscode-drawio.appearance" = "automatic";
        };
      };
    };
}
