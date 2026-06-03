{ config, ... }:
let 
  hyprDir = "${config.home.homeDirectory}/dotfiles/hosts/legion/mark/hypr";
in 
{
  xdg.configFile = builtins.listToAttrs (
    map (name: {
      name = "hypr/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${hyprDir}/${name}";
    }) 
    (builtins.attrNames (builtins.readDir ./hypr))
  );
}