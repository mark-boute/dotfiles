{ lib,    
  libadwaita,
    # yad
  dbus,
  pkg-config,
  atk,
  xdotool,
  gtk3, 
  gtk4, 
  webkitgtk_4_1,
  fetchFromGitHub,
  rustPlatform,
  zsh
}:

let
# https://github.com/NixOS/nixpkgs/tree/nixos-24.05/maintainers
  mark-boute = {
    email = "bmark0702@gmail.com";
    github = "mark-boute";
    githubId = 33718602;
    name = "Mark Boute";
  };
in

rustPlatform.buildRustPackage rec {
  pname = "power-options-daemon";
  version = "591afd6f49ce79cfb5d2d2d1d43e10e64bf44a86";

  src = fetchFromGitHub {
    owner = "TheAlexDev23";
    repo = "power-options";
    rev = version;
    hash = "sha256-gXSJej3Bl2ZnMl3vlSwaknR1yhlaEsRlGctR8abd+GY=";
  };

  cargoHash = "sha256-vsqPhlndM/Do9YQuz5T1EHWhWL0X+7h1rfxipWvwO3Q=";

  buildInputs = [ 
    libadwaita
    # yad
    dbus
    xdotool
    atk 
    gtk3 
    gtk4 
    webkitgtk_4_1
  ];

  nativeBuildInputs = [ 
    zsh
    pkg-config
   ];

  buildAndTestSubdir = "crates/power-daemon-mgr";

  cargoBuildFlags = [
    "--frozen"
    "--release"
  ];


 # cp target/release/power-daemon-mgr $out/bin/

    # cp target/release/frontend-gtk $out/bin/power-options-gtk
    # cp icon.png $out/share/icons/power-options.png
    # cp install/power-options-gtk.desktop $out/share/applications/

  cargoInstallHook = ''
    mkdir -p $out/bin
    install -Dm755 "$src/target/release/power-daemon-mgr" "$out/usr/bin/power-daemon-mgr"
    "$out/usr/bin/power-daemon-mgr" -v generate-base-files --path "$out" --program-path "$out/usr/bin/power-daemon-mgr"
  '';


# package() {
#   cd "$srcdir/power-options-$pkgver"

#   install -Dm755 "target/release/frontend-gtk" "$pkgdir/usr/bin/power-options-gtk"
#   install -Dm755 "icon.png" "$pkgdir/usr/share/icons/power-options-gtk.png"
#   install -Dm755 "install/power-options-gtk.desktop" "$pkgdir/usr/share/applications/power-options-gtk.desktop"
# }




# package() {
#   cd "$srcdir/power-options-$pkgver"

#   install -Dm755 "target/release/power-daemon-mgr" "$pkgdir/usr/bin/power-daemon-mgr"

#   # Generate files
#   "$pkgdir/usr/bin/power-daemon-mgr" -v generate-base-files --path "$pkgdir" --program-path "/usr/bin/power-daemon-mgr"
# }

# post_install() {
#   systemctl daemon-reload
#   systemctl enable power-options.service
#   systemctl start power-options.service
#   systemctl restart acpid.service
# }

# post_upgrade() {
#   systemctl daemon-reload
#   systemctl restart power-options.service
#   systemctl restart acpid.service
# }

# post_remove() {
#   systemctl daemon-reload
# }

  meta = {
    description = "A gtk frontend for Power Options, a blazingly fast power management solution.";
    homepage = "https://github.com/TheAlexDev23/power-options";
    license = lib.licenses.mit;
    maintainers = [ mark-boute];
  };
}