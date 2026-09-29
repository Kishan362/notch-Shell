#!/bin/bash

# copy the config file if it doesn't exists in user's config dir
if [[ ! -f "$HOME/.config/notch-shell/config.jsonc" ]] && [[ -f /usr/share/notch-shell/config.jsonc.example ]]; then
   install -Dm644 /usr/share/notch-shell/config.jsonc.example "$HOME/.config/notch-shell/config.jsonc"
fi

# copy the cava config if it doesn't exists in user's cache dir
if [[ ! -f "$HOME/.cache/notch-shell/cava.conf" ]] && [[ -f /usr/share/notch-shell/scripts/cava.conf ]]; then
   install -Dm644 /usr/share/notch-shell/scripts/cava.conf "$HOME/.cache/notch-shell/cava.conf"
fi

# xkeyboard-config ships a Compose file per locale, but not for every locale
# people actually use - en_IN is one of them. Qt then logs
#   xkbcommon: ERROR: No Compose file for locale "en_IN.ISO8859-1"
#   WARN qt.qpa.input.methods: failed to create compose table
# the moment a text field takes focus (the weather location picker does).
# Point XCOMPOSE at a locale that has one so Ctrl+Shift+u still works.
if [ -z "${XCOMPOSE:-}" ]; then
  _locale="${LC_CTYPE:-${LANG:-en_US.UTF-8}}"
  if ! compgen -G "/usr/share/X11/locale/${_locale}*/Compose" >/dev/null 2>&1; then
    if [ -f /usr/share/X11/locale/en_US.UTF-8/Compose ]; then
      export XCOMPOSE=/usr/share/X11/locale/en_US.UTF-8/Compose
    else
      export XCOMPOSE=""
    fi
  fi
fi

export LD_LIBRARY_PATH="$HOME/.config/quickshell/notch-shell/IslandBackend:$LD_LIBRARY_PATH"
export QML_IMPORT_PATH="/usr/share/notch-shell:$QML_IMPORT_PATH"
exec qs -p /usr/share/notch-shell
