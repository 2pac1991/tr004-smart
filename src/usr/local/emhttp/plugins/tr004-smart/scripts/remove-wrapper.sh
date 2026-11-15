#!/bin/bash
# Stellt das originale smartctl wieder her (Plugin-Deinstallation).
if [ -e /usr/sbin/smartctl.real ]; then
  mv -f /usr/sbin/smartctl.real /usr/sbin/smartctl
fi
rm -f /usr/local/sbin/tr004-smart
logger -t tr004-smart "smartctl-Vermittler entfernt"
