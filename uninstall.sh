#!/bin/bash

if [[ ! "$EUID" -eq 0 ]]; then
   echo "Please run this script as root, i need permissions to delete few files in '/'"
   exit 1
fi

if [[ -e /usr/share/notch-shell ]]; then
   rm -rf /usr/share/notch-shell
fi

if [[ -e /usr/local/bin/notch-shell ]]; then
   rm /usr/local/bin/notch-shell
fi

if [[ -e /usr/share/applications/notch-shell.desktop ]]; then
   rm /usr/share/applications/notch-shell.desktop
fi

if [[ -e /etc/systemd/user/notch-shell.service ]]; then
   rm /etc/systemd/user/notch-shell.service
fi

pkill qs

echo "notch-shell uninstalled successfully :("
