# { inputs, pkgs, lib, config, ... }:

# with lib; let 
#   cfg = config.overlays.steam;
# in {

#   # may now be enabled in configuration.nix with overlays.steam.enable = true;
#   options.overlays.steam = { 
#     enable = mkEnableOption "steam"; 
#   };

#   config = mkIf cfg.enable {
#     pkgs.overlays = [
#       pkgs.overlays.override {
#       steam = pkgs: with pkgs; {
#         steam = pkgs.steam.override {
#           extraPkgs = pkgs: with pkgs; [
#             keyutils
#             libkrb5
#             libpng
#             libpulseaudio
#             libvorbis
#             stdenv.cc.cc.lib
#             xorg.libXcursor
#             xorg.libXi
#             xorg.libXinerama
#             xorg.libXScrnSaver
#           ];
#           extraProfile = "export GDK_SCALE=2";
#         };
#       };
#     }];
#   };
# }
