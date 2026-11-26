{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos.base = { pkgs, lib, ... }: {
    imports = [ nixos.user ];

    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      tmp.cleanOnBoot = true;
      loader = {
        systemd-boot.enable = false;
        timeout = 5;
        efi.canTouchEfiVariables = true;
        grub = {
          enable = true;
          default = "saved";
          efiSupport = true;
          device = "nodev";
          useOSProber = true;
        };
      };
    };

    environment.defaultPackages = [ ];
    services.xserver.desktopManager.xterm.enable = false;

    environment.systemPackages = with pkgs; [
      neovim
      bat
      wget
      zoxide
      git
      fd
      xdg-utils
    ];

    time.timeZone = "Europe/Amsterdam";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    services.openssh.enable = true;
  };
}
