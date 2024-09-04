# NVIDIA

Read: <https://nixos.wiki/wiki/Nvidia>

In order to find your PCI IDs:

`nix-shell -p lshw`
`sudo lshw -c display`

Then format them like:
 > intelBusId = "PCI:0:2:0";
 > nvidiaBusId = "PCI:14:0:0";
