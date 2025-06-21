{
  self,
  config,
  pkgs,
  inputs,
  ...
}: let
  username = "mark";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nixos-hardware.nix
    # ./openvpn.nix
  ];

  main-user = {
    enable = true;
    sudoUser = true;
    userName = username;
    description = "Mark Boute";
    shell = pkgs.zsh;
    groups = ["docker"];
  };

  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  time.hardwareClockInLocalTime = true;

  programs = {
    thunderbird.enable = true;
    tmux.enable = true;
    hyprland.enable = true;
  };

  modules = {
    system.gpu.optimus-prime = {
      enable = true;
      mode = "offload";
      cpu = "amd";
      open = true;
      setDeviceIds = true;
      cpuId = "PCI:1:0:0";
      gpuId = "PCI:5:0:0";
      powerManagement = false;
      finegrained = true;
      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.beta;
    };
    steam = {
      enable = true;
      addprotonup = true;
    };
    winapps.enable = true;
    sops.enable = true;
  };

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs;
    [
      # kitty

      powertop
      nvtopPackages.full

      # cora dependencies
      z3
      jdk23
      gradle-completion
      cmake
      unzip

      nixfmt-rfc-style

      vscode-fhs
      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions;
          [
            bbenoist.nix
            # ms-python.python
            ms-azuretools.vscode-docker
            ms-vscode-remote.remote-ssh
            vscjava.vscode-java-pack
            vscjava.vscode-gradle
          ]
          ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
            {
              name = "remote-ssh-edit";
              publisher = "ms-vscode-remote";
              version = "0.47.2";
              sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
            }
          ];
      })
    ]
    ++ [
      inputs.zen-browser.packages.${system}.default
      self.packages.${system}.neovim-mark
    ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Enable numlock on GDM login screen
  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
    }
  ];

  # Enable networking
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;

  services = {
    cloudflare-warp.enable = true;
    printing.enable = true;
    pulseaudio.enable = false;
    libinput.enable = true;

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    xserver.xkb = {
      # Configure keymap in X11
      layout = "us";
      variant = "";
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;
    };
  };
}
