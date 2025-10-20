{ ... }:
{
  config = {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Mark Boute";
          email = "bmark0702@gmail.com";
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

        push = {autoSetupRemote = true;};
        init = {defaultBranch = "main";};
      };
    };

    programs.diff-so-fancy = { 
      enable = true;
      enableGitIntegration = true;
    };
  };
}