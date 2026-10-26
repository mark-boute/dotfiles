# pkgs/uni-printers.nix
{ stdenv, perl, lib }:

stdenv.mkDerivation {
  pname = "km-printer";
  version = "1";
  src = ./drivers;
  buildInputs = [ perl ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/cups/model $out/lib/cups/filter
    cp ppd/*.ppd  $out/share/cups/model/
    cp filter/*   $out/lib/cups/filter/
    chmod 755 $out/lib/cups/filter/*
    runHook postInstall
  '';
}
