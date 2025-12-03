{ pkgs, inputs, ... }: {
  # ...
  nixpkgs = { 
    overlays = [
      (final: prev: {  # make nvchad available system-wide
        nvchad = inputs.nix4nvchad.packages."${pkgs.stdenv.hostPlatform.system}".nvchad;
      })
    ];
  };
  # ...
}