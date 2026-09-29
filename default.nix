{ pkgs ? import <nixpkgs> {} }:

let
qtModules = with pkgs.qt6; [
  qtbase
  qtdeclarative
  qtmultimedia
];
qmlImportPath = pkgs.lib.concatMapStringsSep ":" (m: "${m}/lib/qt-6/qml") qtModules;
qtPluginPath  = pkgs.lib.concatMapStringsSep ":" (m: "${m}/lib/qt-6/plugins") qtModules;

nusgmonPython = pkgs.python3.withPackages (ps: [ ps.psutil ]);
scriptsPython = pkgs.python3.withPackages (ps: [ ps.holidays ]);

nusgmon = pkgs.stdenv.mkDerivation {
  pname = "nusgmon";
  version = "unstable-2024";
  src = pkgs.fetchFromGitHub {
    owner = "LUCKYS1NGHH";
    repo = "nusgmon";
    rev = "a896594";
    sha256 = "sha256-WTJ/jr+MawJsSIXAGi7itEo8/QJ54Po4FJ2ASw8/64Q=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/share/nusgmon
    cp -r . $out/share/nusgmon

    makeWrapper ${nusgmonPython}/bin/python3 $out/bin/nusgmon \
      --add-flags "$out/share/nusgmon/nusgmon"

    install -Dm644 config.toml $out/share/nusgmon/config.toml.example
  '';
};

   runtimeDeps = with pkgs; [
     cava
     quickshell
     cliphist
     brightnessctl
     wl-clipboard
     inotify-tools
     pipewire
     pulseaudio
     blueman
     awww
     nusgmon
   ];
in
pkgs.stdenv.mkDerivation rec {
  pname = "notch-shell";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    makeWrapper
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qttools
    qt6.qtmultimedia
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_LIBDIR=lib"
  ];

  installPhase = ''
    runHook preInstall

    cmake --install .

    install -Dm755 $src/launcher.sh $out/bin/notch-shell
    substituteInPlace $out/bin/notch-shell \
      --replace '/usr/share/notch-shell' "$out/share/notch-shell" \
      --replace '$HOME/.config/quickshell/notch-shell/IslandBackend' "$out/lib/qt6/qml/IslandBackend"

    cat > $out/bin/notch-shell-ipc <<'WRAPPER'
  #!/usr/bin/env bash
  exec REPLACE_QS ipc -p REPLACE_CONFIG_PATH "$@"
  WRAPPER
    chmod +x $out/bin/notch-shell-ipc
    substituteInPlace $out/bin/notch-shell-ipc \
      --replace REPLACE_QS "${pkgs.quickshell}/bin/qs" \
      --replace REPLACE_CONFIG_PATH "$out/share/notch-shell"

    mkdir -p $out/share/notch-shell
    cp -r $src/qml/*   $out/share/notch-shell/
    cp -r $src/share   $out/share/notch-shell/
    cp -r $src/scripts $out/share/notch-shell/
    install -Dm644 $src/config.jsonc $out/share/notch-shell/config.jsonc.example

    chmod +x $out/share/notch-shell/scripts/*
    PATH="${scriptsPython}/bin:$PATH" patchShebangs $out/share/notch-shell/scripts

    grep -rl '/usr/share/notch-shell' $out/share/notch-shell | while read -r f; do
      substituteInPlace "$f" --replace '/usr/share/notch-shell' "$out/share/notch-shell"
    done

    install -Dm644 $src/notch-shell.desktop $out/share/applications/notch-shell.desktop
    substituteInPlace $out/share/applications/notch-shell.desktop \
      --replace 'Exec=notch-shell' "Exec=$out/bin/notch-shell"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/notch-shell \
      --set QML_IMPORT_PATH "$out/share/notch-shell:$out/lib/qt6/qml:${qmlImportPath}" \
      --set QT_PLUGIN_PATH "${qtPluginPath}" \
      --set LD_LIBRARY_PATH "$out/lib/qt6/qml/IslandBackend" \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = with pkgs.lib; {
    description = "notch-shell (Wayland bar) fork - notch-shell";
    homepage = "https://github.com/PinguinAdvokat/notch-shell";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "notch-shell";
  };
}
