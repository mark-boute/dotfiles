{ config, ... }:
{
  xdg.configFile = {
    "hypr/monitors.lua".source = config.lib.file.mkOutOfStoreSymlink 
      "${config.home.homeDirectory}/dotfiles/hosts/legion/mark/monitors.lua";
  };
}