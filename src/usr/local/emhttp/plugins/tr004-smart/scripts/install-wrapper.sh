#!/bin/bash
# Setzt den smartctl-Vermittler ein (laeuft bei jeder Plugin-Installation, also auch nach jedem Start).
PLUG=/usr/local/emhttp/plugins/tr004-smart
set -e
if [ ! -e /usr/sbin/smartctl.real ]; then
  mv /usr/sbin/smartctl /usr/sbin/smartctl.real
fi
install -m 755 "$PLUG/smartctl-wrapper" /usr/sbin/smartctl
install -m 755 "$PLUG/tr004-smart" /usr/local/sbin/tr004-smart
mkdir -p /var/lib/tr004-smart
logger -t tr004-smart "smartctl-Vermittler eingesetzt"
