{ inputs, ... }:
{
  # flake.modules.<class>.<name>: the aspect registry every other file adds to
  imports = [ inputs.flake-parts.flakeModules.modules ];

  systems = [ "x86_64-linux" ];
}
