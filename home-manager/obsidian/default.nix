{ config, lib, pkgs, ... }:
let
  cfg = config.programs.obsidian.vaultEnvs;

  launcher = pkgs.writeShellApplication {
    name = "obsidian-vault-launch";
    runtimeInputs = [ cfg.package pkgs.direnv ];
    text = ''
      id="$1"
      vault="$2"
      data="$HOME/.local/share/obsidian-vaults/$id"
      cd "$vault"

      if [ -f .envrc ]; then
        exec direnv exec "$vault" obsidian \
          --user-data-dir="$data" --class="obsidian-$id"
      elif [ -f flake.nix ]; then
        exec nix develop --command obsidian \
          --user-data-dir="$data" --class="obsidian-$id"
      else
        exec obsidian --user-data-dir="$data" --class="obsidian-$id"
      fi
    '';
  };

  indexer = pkgs.writeShellApplication {
    name = "obsidian-vault-index";
    runtimeInputs = [ pkgs.jq pkgs.coreutils ];
    text = ''
      cfg="$HOME/.config/obsidian/obsidian.json"
      apps="$HOME/.local/share/applications"
      state="$HOME/.local/share/obsidian-vaults"

      mkdir -p "$apps" "$state"
      rm -f "$apps"/obsidian-vault-*.desktop
      [ -f "$cfg" ] || exit 0

      jq -r '.vaults | to_entries[] | [.key, .value.path] | @tsv' "$cfg" |
      while IFS=$'\t' read -r id path; do
        [ -d "$path" ] || continue
        name="$(basename "$path")"

        # Seed a private config so this instance opens only this vault
        if [ ! -f "$state/$id/obsidian.json" ]; then
          mkdir -p "$state/$id"
          jq --arg id "$id" \
            '{vaults: {($id): (.vaults[$id] + {open: true})}}' \
            "$cfg" > "$state/$id/obsidian.json"
        fi

        cat > "$apps/obsidian-vault-$id.desktop" <<EOF
      [Desktop Entry]
      Type=Application
      Name=Obsidian: $name
      Icon=obsidian
      Exec=${launcher}/bin/obsidian-vault-launch $id "$path"
      Categories=Office;
      StartupWMClass=obsidian-$id
      EOF
      done
    '';
  };
in
{
  options.programs.obsidian.vaultEnvs = {
    enable = lib.mkEnableOption "per-vault Obsidian launchers that open in each vault's direnv/flake environment";
    
    hideNormalApp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Hide the stock Obsidian launcher from GNOME (sets NoDisplay=true in a
        user-level override of obsidian.desktop). The obsidian:// URL handler
        keeps working.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.obsidian;
      defaultText = lib.literalExpression "pkgs.obsidian";
      description = "The Obsidian package the per-vault launchers run.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ launcher indexer ]
        # Don't install Obsidian twice if home-manager's own module already does
        ++ lib.optional (!(config.programs.obsidian.enable or false)) cfg.package;

      systemd.user.services.obsidian-vault-index = {
        Unit.Description = "Generate per-vault Obsidian launchers";
        Service = {
          Type = "oneshot";
          ExecStart = "${indexer}/bin/obsidian-vault-index";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.paths.obsidian-vault-index = {
        Unit.Description = "Watch obsidian.json for vault changes";
        Path.PathChanged = "%h/.config/obsidian/obsidian.json";
        Install.WantedBy = [ "default.target" ];
      };
    })
    
    (lib.mkIf (cfg.enable && cfg.hideNormalApp) {
      # A user-level .desktop file with the same ID shadows the package's own
      xdg.desktopEntries.obsidian = {
        name = "Obsidian";
        exec = "obsidian %U";
        icon = "obsidian";
        categories = [ "Office" ];
        mimeType = [ "x-scheme-handler/obsidian" ];
        startupNotify = true;
        noDisplay = true;
        settings.StartupWMClass = "obsidian";
      };
    })

    # Remove the generated launchers when the option is turned off,
    # since they live outside the Nix store and would otherwise linger
    (lib.mkIf (!cfg.enable) {
      home.activation.removeObsidianVaultLaunchers =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME"/.local/share/applications/obsidian-vault-*.desktop
        '';
    })
  ];
}
