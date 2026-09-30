#!/bin/bash

set -euo pipefail

skip_arg=${1:-}

# colors
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
BLUE_BG='\e[1;44m'
BLACK='\e[1;30m'
NC='\e[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

bin_exists() { command -v "$1" >/dev/null; }

if [[ ! "$EUID" -eq 0 ]]; then
    die "Please run this script as root to install notch-shell. i have to setup some things."
fi

needed_pkgs=(quickshell cliphist brightnessctl
             wl-clipboard inotify-tools cmake
             qt6-multimedia python-psutil blueman pipewire
)

missing_pkgs=()

if [[ "$skip_arg" != "--skip-deps" ]]; then
  if command -v pacman &>/dev/null; then

      for pkg in "${needed_pkgs[@]}"; do
          pacman -Qi "$pkg" &>/dev/null || missing_pkgs+=("$pkg")
      done

      if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
         info "Installing dependencies in your Arch Linux."
         pacman -S --needed --noconfirm "${missing_pkgs[@]}"
      else
         info "All dependencies installed, skipping."
      fi

      PY=/usr/bin/python3

      if ! sudo -u "$SUDO_USER" "$PY" -m pip show holidays >/dev/null 2>/dev/null; then
         read -p "Do you want event dates in calendar popup? It just needs a python lib 'holidays' to run [y/N]: " ask

         if [[ "$ask" == "y" || "$ask" == "Y" ]]; then
            if ! sudo -u "$SUDO_USER" "$PY" -m pip --version >/dev/null 2>/dev/null; then
               read -p "Pip not exists in your system. install? [Y/n]: " pip_install
               if [[ "$pip_install" != "n" && "$pip_install" != "N" ]]; then
                  pacman -S --noconfirm python-pip
               fi
            fi

            if sudo -u "$SUDO_USER" "$PY" -m pip --version >/dev/null 2>/dev/null; then
               sudo -u "$SUDO_USER" "$PY" -m pip install holidays --break-system-packages 2>/dev/null \
                 || warn "something wrong with pip, 'holidays' python lib fail to install."

               sudo -u "$SUDO_USER" "$PY" -c "import holidays" 2>/dev/null \
                 || warn "holidays installed but failing to import. check the dependency manually."
            fi
         fi
      fi

  fi
fi

bin_exists awww || warn "Awww not installed. it will be needed if you don't use custom wallpaper script."
bin_exists quickshell || die "Quickshell not installed."
bin_exists cliphist || die "Cliphist not installed."
bin_exists sensors || die "lm_sensors not installed. it provides the CPU temperature."
bin_exists inotifywait || die "Inotify not installed."
bin_exists brightnessctl || die "Brightnessctl not installed."
bin_exists cmake || die "Cmake not installed."
bin_exists blueman-manager || warn "Blueman not installed." # warn here because not everyone use bluetooth
bin_exists pipewire || die "Pipewire not installed."
bin_exists wl-copy || die "Wl-clipboard not installed."
(bin_exists NetworkManager || bin_exists iw) || die "Need a network manager: NetworkManager or iw (recommended is NetworkManager, for bar's extra vpn module)"
bin_exists nmcli || warn "nmcli not installed. if you will use vpn module in bar, nmcli is needed."

REAL_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

if [[ -z "$REAL_HOME" ]]; then
   warn "Your home directory not found."
   while true; do
     read -p "Enter your home directory manually: " REAL_HOME
     if [[ -z "$REAL_HOME" ]]; then
        continue
     fi
     if [[ ! -d "$REAL_HOME" ]]; then
        warn "Directory not found."
        continue
     fi
     break
   done
fi

# make directories
info "Creating few new directories"
mkdir -p /usr/share/notch-shell/IslandBackend
mkdir -p "$REAL_HOME/.config/notch-shell/modules"
mkdir -p "$REAL_HOME/.cache/notch-shell"
#mkdir -p /etc/systemd/user

# build backend
SRC_FILES=$(find . -name '*.cpp' -o -name '*.h' -o -name 'CMakeLists.txt')
HASH_FILE='.builds_hash'

backend_files=(
  IslandBackend.qmltypes
  libIslandBackendPlugin.so
  libIslandBackend.so
  qmldir
)

needs_build=true
if [[ -f "$HASH_FILE" ]]; then
    if sha256sum -c "$HASH_FILE" --status 2>/dev/null; then
        all_exist=true
        for file in "${backend_files[@]}"; do
            if [[ ! -f "/usr/share/notch-shell/IslandBackend/$file" ]]; then
                all_exist=false
                break
            fi
        done
        if $all_exist; then
            needs_build=false
        fi
    fi
fi

if $needs_build; then
    info "Building backend from source files"
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j$(nproc)

    info "Copying backend files"
    install -m 644 \
       build/libIslandBackend.so \
       build/libIslandBackendPlugin.so \
       build/qmldir \
       build/IslandBackend.qmltypes \
         /usr/share/notch-shell/IslandBackend

    echo "$SRC_FILES" | xargs sha256sum > "$HASH_FILE"
else
    info "No backend source changes, skipping backend build"
fi

# copy directories
info "Copying scripts and share directory to /usr/share/notch-shell"
cp -r scripts /usr/share/notch-shell
cp -r share /usr/share/notch-shell
cp -r templates /usr/share/notch-shell

# copy QML files
info "Copying QML files"
install -m 644 qml/* /usr/share/notch-shell

# copy launcher (bash)
info "Copying the launcher.sh"
install -m 755 launcher.sh /usr/local/bin/notch-shell

# copy app launcher
info "Copying app launcher"
install -m 644 notch-shell.desktop /usr/share/applications

# set correct permissions at last
info "Setting up right permissions"

chmod 755 /usr/share/notch-shell
chmod 755 /usr/share/notch-shell/share
chmod 644 /usr/share/notch-shell/share/*
chmod 755 /usr/share/notch-shell/scripts
chmod 755 /usr/share/notch-shell/scripts/*
chmod 755 /usr/share/notch-shell/IslandBackend
chmod 644 /usr/share/notch-shell/IslandBackend/*
chmod 755 "$REAL_HOME/.config/notch-shell/modules"

# chown back the files permission to real user
chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REAL_HOME/.config/notch-shell"
chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REAL_HOME/.cache/notch-shell"

# setup config file
info "Setting up config file"
install -m 644 config.jsonc /usr/share/notch-shell/config.jsonc.example

if [[ -f "$REAL_HOME/.config/notch-shell/config.jsonc" ]]; then
   info "Updating your config file..."
   if [[ -f scripts/config_update.py ]] && bin_exists python3; then
      python3 scripts/config_update.py "$SUDO_USER" || warn "Config file update failed."
   else
      warn "scripts/config_update.py missing OR python not installed, skipping config update."
   fi
else
   install -m 644 config.jsonc "$REAL_HOME/.config/notch-shell/config.jsonc"
fi

# place systemd file
#info "Copying systemd file to /etc/systemd/user"
#install -m 644 notch-shell.service /etc/systemd/user/notch-shell.service

# minor adjustments
info "Few adjustments"
if [[ -f /usr/share/notch-shell/scripts/cpu-temp.sh ]]; then
   mv /usr/share/notch-shell/scripts/cpu-temp.sh "$REAL_HOME/.config/notch-shell/modules/cpu-temp.sh"
   chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REAL_HOME/.config/notch-shell/modules/cpu-temp.sh"
fi

# point wallust at notch-shell's theme template, if wallust is installed
if bin_exists wallust && [[ -f scripts/setup_wallust.py ]]; then
   info "Setting up wallust dynamic theming"
   sudo -u "$SUDO_USER" HOME="$REAL_HOME" python3 scripts/setup_wallust.py \
      || warn "wallust setup failed. The built-in sampler will be used instead."
fi

# cleaning build files
info "Cleaning up build files"
rm -rf build


echo -e "\nRun the command '${GREEN}notch-shell${NC}' to start now."
echo -e "or open '${GREEN}Notch Shell${NC}' through your app launcher."

# if needed backend build, that probably (partially) means a new user, so only show auto-run command paste code to them
if $needs_build; then
   echo -e "\nTo auto-run at every startup, paste this code in your ${BLUE_BG} ${BLACK}~/.config/hypr/hyprland.lua ${NC} config:"
   echo -e "${BLUE}hl.on(\"hyprland.start\", function()\n   hl.exec_cmd(\"notch-shell\")\nend)${NC}\n"
fi
