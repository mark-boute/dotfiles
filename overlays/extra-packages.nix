{ pkgs, inputs, ... }: {
  # ...
  nixpkgs = { 
    overlays = [
      (final: prev: {  # make nvchad available system-wide
        nvchad = inputs.nix4nvchad.packages."${pkgs.stdenv.hostPlatform.system}".nvchad;
      })
      (final: prev: {  # sphinx man builder no longer runs, so the man output is never created
        khal = prev.khal.overridePythonAttrs (old: {
          outputs = [ "out" "doc" ];
          sphinxBuilders = [ "html" ];
        });
      })
    ];
  };
  # ...
}