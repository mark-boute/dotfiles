{ ... }:
{
  config = {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Ties Dirksen";
          email = "tiesdirksen@gmail.com";
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