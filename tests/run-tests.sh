#!/bin/bash
# Testet die Sicherheitslogik von tr004-smart mit simulierten Platten (Dateien) und einem
# smartctl-Ersatz, der absichtlich Sektoren zerstoert - so wie es beim TR-004 passiert ist.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }

mkdir -p "$T/bin" "$T/dev" "$T/state"
# flock-Ersatz fuer macOS
command -v flock >/dev/null || { printf '#!/bin/sh\nexit 0\n' > "$T/bin/flock"; chmod +x "$T/bin/flock"; }

# --- simulierte Platten ---------------------------------------------------------------
mk_mbr() {  # MBR, Partition 1 ab Sektor 64 (wie Unraid bei <2 TB)
  dd if=/dev/zero of="$1" bs=512 count=2048 2>/dev/null
  printf '\x83' | dd of="$1" bs=1 seek=$((446+4)) conv=notrunc 2>/dev/null
  printf '\x40\x00\x00\x00' | dd of="$1" bs=1 seek=$((446+8)) conv=notrunc 2>/dev/null
  printf '\x00\x00\x10\x00' | dd of="$1" bs=1 seek=$((446+12)) conv=notrunc 2>/dev/null
  printf '\x55\xaa' | dd of="$1" bs=1 seek=510 conv=notrunc 2>/dev/null
  printf 'XFSB' | dd of="$1" bs=512 seek=64 conv=notrunc 2>/dev/null
}
mk_gpt() {  # GPT, 128 Eintraege ab LBA 2 (Tabelle bis 33), Partition ab 64
  dd if=/dev/zero of="$1" bs=512 count=2048 2>/dev/null
  printf '\x55\xaa' | dd of="$1" bs=1 seek=510 conv=notrunc 2>/dev/null
  printf 'EFI PART' | dd of="$1" bs=1 seek=512 conv=notrunc 2>/dev/null
  printf '\x02\x00\x00\x00\x00\x00\x00\x00' | dd of="$1" bs=1 seek=$((512+72)) conv=notrunc 2>/dev/null
  printf '\x80\x00\x00\x00' | dd of="$1" bs=1 seek=$((512+80)) conv=notrunc 2>/dev/null
  printf '\x80\x00\x00\x00' | dd of="$1" bs=1 seek=$((512+84)) conv=notrunc 2>/dev/null
  printf '\xaf\x3d\xc6\x0f' | dd of="$1" bs=1 seek=1024 conv=notrunc 2>/dev/null
  printf '\x40\x00\x00\x00\x00\x00\x00\x00' | dd of="$1" bs=1 seek=$((1024+32)) conv=notrunc 2>/dev/null
}
reset_disks() {
  mk_gpt "$T/dev/usb-QNAP_TR-004_DISK00-0:0"
  mk_mbr "$T/dev/usb-QNAP_TR-004_DISK01-0:0"
}

# --- smartctl-Ersatz: zerstoert Briefkasten-Sektor UND Sektor 0 aller Platten ---------
cat > "$T/bin/smartctl" <<'EOF'
#!/bin/bash
dev="${!#}"; typ="$2"; lba="${typ##*,s}"
printf '%%\x03\x7b\x19PAKET' | dd of="$dev" bs=512 seek="$lba" conv=notrunc 2>/dev/null
[ "${MOCK_WIPE0:-1}" = 1 ] && for d in "$MOCK_DEVDIR"/*; do dd if=/dev/zero of="$d" bs=512 count=1 conv=notrunc 2>/dev/null; done
port=$(echo "$typ" | cut -d, -f2)
echo "{\"model_name\":\"MOCK$port\",\"serial_number\":\"SN$port\",\"smart_status\":{\"passed\":true},\"temperature\":{\"current\":3$port},\"power_on_time\":{\"hours\":100},\"ata_smart_attributes\":{\"table\":[{\"id\":5,\"raw\":{\"value\":0}},{\"id\":197,\"raw\":{\"value\":$port}}]}}"
EOF
chmod +x "$T/bin/smartctl"

export PATH="$T/bin:$PATH" MOCK_DEVDIR="$T/dev"
export TR004_CONF=/nonexistent TR004_STATE_DIR="$T/state" TR004_DEV_GLOB="$T/dev/usb-QNAP_TR-004_DISK*-0:0"
export TR004_ENABLED_FLAG="$T/enabled" TR004_LOCK="$T/lock" QUIET=1
S="$ROOT/tr004-smart"
sha() { shasum "$T/dev/"* | awk '{print $1}' | tr '\n' ' '; }

echo "Test 1: Pruefung erkennt GPT und MBR, Sektor 48 frei"
reset_disks
out=$(bash "$S" list 2>&1); echo "$out" | grep -q "gpt, 1. Partition ab 64" && echo "$out" | grep -q "mbr, 1. Partition ab 64" && ok "Layouts erkannt" || { bad "Layouts"; echo "$out"; }

echo "Test 2: Sektor 33 wird verweigert"
TR004_MAILBOX_LBA=33 bash "$S" list 2>&1 | grep -q "Sektor 33 ist gesperrt" && ok "33 gesperrt" || bad "33 nicht gesperrt"

echo "Test 3: Sektor in GPT-Tabelle wird verweigert"
TR004_MAILBOX_LBA=20 bash "$S" list 2>&1 | grep -q "liegt in der GPT-Tabelle" && ok "GPT-Tabelle geschuetzt" || bad "GPT-Tabelle"

echo "Test 4: belegter Sektor (altes JMicron-Paket) wird verweigert"
reset_disks
for d in "$T/dev/"*; do printf '%%\x03\x7b\x19' | dd of="$d" bs=512 seek=48 conv=notrunc 2>/dev/null; done
bash "$S" list 2>&1 | grep -q "altes JMicron-Paket" && ok "Rest erkannt" || bad "Rest nicht erkannt"
bash "$S" check >/dev/null 2>&1 && bad "check haette fehlschlagen muessen" || ok "check schlaegt fehl"

echo "Test 5: ohne Freischaltung wird nichts geschrieben"
reset_disks; before=$(sha)
bash "$S" read >/dev/null 2>&1; [ "$(sha)" = "$before" ] && ok "nichts veraendert" || bad "Platten veraendert"

echo "Test 6: Lesen mit zerstoererischem smartctl - alles wird wiederhergestellt"
reset_disks; before=$(sha); touch "$T/enabled"
out=$(bash "$S" read --json 2>"$T/err")
[ "$(sha)" = "$before" ] && ok "Platten bitgenau wie vorher" || { bad "Platten veraendert"; cat "$T/err"; }
[ "$(echo "$out" | jq length)" = 4 ] && ok "4 Einschuebe gelesen" || { bad "Ergebnis: $out"; }
[ "$(echo "$out" | jq '.[1].temp')" = 31 ] && ok "Temperatur Port 1 = 31" || bad "Temperatur"
grep -q "Sektor 0 wurde veraendert" "$T/err" && ok "Schaden gemeldet" || bad "keine Warnung"

echo "Test 7: Abbruch mitten im Lauf - Sektoren trotzdem wiederhergestellt"
reset_disks; before=$(sha)
cat > "$T/bin/smartctl" <<'EOF'
#!/bin/bash
dev="${!#}"; lba="${2##*,s}"
printf '%%\x03\x7b\x19' | dd of="$dev" bs=512 seek="$lba" conv=notrunc 2>/dev/null
kill -TERM $PPID; sleep 1
EOF
bash "$S" read >/dev/null 2>&1
[ "$(sha)" = "$before" ] && ok "nach Abbruch bitgenau wie vorher" || bad "nach Abbruch veraendert"

echo
echo "Ergebnis: $pass ok, $fail fehlgeschlagen"
[ $fail -eq 0 ]
