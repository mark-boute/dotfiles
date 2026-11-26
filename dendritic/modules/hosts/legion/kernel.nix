{
  flake.modules.nixos.legion-kernel =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
      warnings = [
        "legion: kmodigest signing workaround for zenpower/lenovo-legion-module is still in kernel.nix; build without it after an update to see if nixpkgs fixed it"
      ];
      # nixpkgs (2026-10) signs modules with kmodigest and merges each external
      # module's .ko.cer; these two copy their .ko by hand and ship none
      boot.kernelPackages = pkgs.linuxPackages_latest.extend (
        _: prev:
        let
          sign =
            drv:
            drv.overrideAttrs (old: {
              postFixup = (old.postFixup or "") + ''
                find $out -name '*.ko' ! -exec test -e {}.cer \; -exec ${lib.getExe pkgs.buildPackages.kmodigest} {} \;
              '';
            });
        in
        {
          zenpower = sign prev.zenpower;
          lenovo-legion-module = sign prev.lenovo-legion-module;
        }
      );
    };
}
