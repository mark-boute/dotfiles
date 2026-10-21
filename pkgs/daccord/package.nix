{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  gtk3,
  libepoxy,
  libdrm,
  libgbm,
  libsecret,
  mpv-unwrapped,
  vulkan-loader,
  fontconfig,
  zlib,
  gst_all_1,
  xorg,
  alsa-lib,
  libpulseaudio,
  libGL,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "daccord";
  version = "0.2.26";

  src = fetchurl {
    url = "https://github.com/DaccordProject/daccord/releases/download/v${finalAttrs.version}/daccord-linux-x86_64.deb";
    hash = "sha256-Q0FAadOgz6LxdNjpp0yMt77N26aySASjrKUS+NAPfak=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    libepoxy
    libdrm
    libgbm
    libsecret
    mpv-unwrapped
    vulkan-loader
    fontconfig
    zlib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -r opt/daccord $out/share/daccord
    cp -r usr/share/applications usr/share/icons $out/share/
    substituteInPlace $out/share/applications/daccord.desktop \
      --replace-fail "Exec=daccord" "Exec=$out/bin/daccord"

    runHook postInstall
  '';

  # libwebrtc dlopens audio and GL libraries at runtime
  postFixup = ''
    makeWrapper $out/share/daccord/daccord $out/bin/daccord \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          alsa-lib
          libpulseaudio
          libGL
        ]
      }
  '';

  meta = {
    description = "Open-source chat, voice and video client for accordserver instances";
    homepage = "https://www.daccord.gg";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "daccord";
  };
})
