{ config, ... }:
{
  flake.modules.nixos.git = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.git ];
  };

  flake.modules.homeManager.git = { osConfig, ... }: {
    programs.git = {
      enable = true;
      signing.format = "ssh";
      settings = {
        user = {
          name = osConfig.my.user.fullName;
          email = osConfig.my.user.email;
        };
        alias = {
          s = "status";
          c = "commit";
          b = "switch"; # yep, this is on purpose
          d = "diff";
          l = "log";
          p = "push";
          u = "pull";
          f = "fetch";
          a = "add";
        };

        push = { autoSetupRemote = true; };
        init = { defaultBranch = "main"; };
      };
    };

    programs.diff-so-fancy = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
