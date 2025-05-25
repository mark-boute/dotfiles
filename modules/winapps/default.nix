{ inputs, config, lib, main-user, ... }:

with lib; let 
  cfg = config.modules.winapps; 

in {
  options.modules.winapps = { 
    enable = mkEnableOption "Winapps";
  };

  config = mkIf cfg.enable {
    
    modules.sops.enable = true;
    sops.secrets = {
      windows = {
        sopsFile = ../../secrets/${main-user}/windows.env;
        format = "dotenv";
        owner = main-user;
      };
    };

    environment.systemPackages = [
      inputs.winapps.packages."x86_64-linux".winapps
      inputs.winapps.packages."x86_64-linux".winapps-launcher

    ];

    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
      # https://github.com/winapps-org/winapps
      "WinApps" = {
        serviceName = "WinApps";
        image = "ghcr.io/dockur/windows:latest";
        environment = {
          "VERSION" = "11";
          "RAM_SIZE" = "4G";
          "CPU_CORES" = "4";
          "DISK_SIZE" = "64G";
          "USERNAME" = main-user;
          "HOME" = "/home/${main-user}";
        };
        environmentFiles = [ 
          config.sops.secrets.windows.path
        ];
        ports = [
          "8006:8006"
          "3389:3389/tcp"
          "3389:3389/udp"
        ];
        extraOptions = [ 
          "--cap-add=NET_ADMIN"
          "--cap-add=CAP_NET_RAW"
          "--sysctl=net.ipv4.ip_forward=1"
        ];
        volumes = [
          "/var/lib/windows:/storage"
          "/home/${main-user}:/shared"
          "/home/${main-user}/dotfiles/modules/winapps/oem:/oem"
        ];
        devices = [
          "/dev/kvm"
          "/dev/net/tun"
        ];
        autoStart = false;
      };
    };
  };
}