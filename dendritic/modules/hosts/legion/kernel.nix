{
  flake.modules.nixos.legion-kernel = { config, pkgs, lib, ... }: {
    boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
    # nixpkgs (2026-10) signs modules with kmodigest and merges each external
    # module's .ko.cer; these two copy their .ko by hand and ship none
    boot.kernelPackages = pkgs.linuxPackages_latest.extend (_: prev: let
      sign = drv: drv.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          find $out -name '*.ko' ! -exec test -e {}.cer \; -exec ${lib.getExe pkgs.buildPackages.kmodigest} {} \;
        '';
      });
    in {
      zenpower = sign prev.zenpower;
      lenovo-legion-module = sign prev.lenovo-legion-module;
    });
  };
}
