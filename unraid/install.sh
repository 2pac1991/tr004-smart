#!/bin/bash
# Installiert den smartctl-Vermittler. Muss nach jedem Unraid-Start laufen, daher in /boot/config/go:
#   bash /boot/config/custom/tr004-install.sh
set -e
SRC=/boot/config/custom/smartctl-tr004-wrapper
[ -f "$SRC" ] || { echo "fehlt: $SRC" >&2; exit 1; }
if [ ! -e /usr/sbin/smartctl.real ]; then
  mv /usr/sbin/smartctl /usr/sbin/smartctl.real
fi
install -m 755 "$SRC" /usr/sbin/smartctl
mkdir -p /var/lib/tr004-smart
# gleich einmal lesen, damit Unraid sofort Werte hat
[ -f /boot/config/tr004-smart.enabled ] && (sleep 60; /bin/bash /boot/config/custom/tr004-smart read >/dev/null 2>&1) &
logger -t tr004-smart "smartctl-Vermittler installiert"
