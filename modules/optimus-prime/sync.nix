{
  # This needs device IDs to be set! See:
  # https://github.com/vimjoyer/nixos-gaming-video
  # if possible use:
  # https://github.com/NixOS/nixos-hardware

  hardware.nvidia.prime = {
    sync.enable = true;

    # # integrated
    # amdgpuBusId = "PCI:6:0:0"
    # intelBusId = "PCI:0:0:0";

    # # dedicated
    # nvidiaBusId = "PCI:1:0:0";
  };

}