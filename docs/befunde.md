# Befunde: Wie die QNAP-Software den TR-004 abfragt

Untersucht wurde der *QNAP External RAID Manager* für macOS (App `QNAPRaidMgr`,
Hintergrunddienst `QNAP External RAID Manager Service`, Bibliothek `libjmUsbScsi.dylib`)
mit einem TR-004 (USB `1c04:e014`, Firmware-Kennung „QNAP TR-004 DISK0x").
Es wurden nur Symbole und Maschinencode gelesen; der Dienst wurde während der Analyse gestoppt.

## Zwei Kanäle

| Kanal | Weg | Wofür |
|---|---|---|
| Hersteller-SCSI-Befehle | `libjmUsbScsi` → Kernel-Erweiterung `jmPeripheralDevice.kext` → `WRITE BUFFER (0x3B)` / `READ BUFFER (0x3C)` an die USB-Bridge | Chip-Infos, NVRAM, Register, Firmware-Update |
| Briefkasten-Sektor | App → lokaler Socket → Root-Dienst → `open/read/write` auf `/dev/diskN` | **SMART**, Temperatur, RAID-Status |

Der SMART-Weg (`JMRaidMgrMan::getDiskSmartInfo`) baut einen ATA-Befehl
(`B0h`, Feature `D0h` SMART READ DATA bzw. `D1h` READ THRESHOLDS, LBA `C24F00h`)
und schickt ihn über den Briefkasten (`_SentFisCmd`). Der Hersteller-SCSI-Kanal wird dafür
**nicht** verwendet. Einen Weg, SMART ohne Schreibzugriff auf eine Platte zu bekommen,
hat die QNAP-Software also selbst nicht.

Auf Apple-Silicon-Macs ist die Kernel-Erweiterung standardmäßig nicht geladen.
Der SMART-Weg funktioniert trotzdem, weil er nur rohe Plattenzugriffe braucht.

## Spuren auf echten Platten

Auf einer 1-TB-Platte (Unraid, MBR-Layout, Partition ab Sektor 64) fanden sich:

* Sektor 0 komplett leer (MBR samt Signatur `55AA` weg), XFS ab Sektor 64 unversehrt
* in den Sektoren 33 und 39 je ein Paket mit Kennung `25 03 7B 19` (= `0x197B0325`),
  gefolgt von Füllbytes `10 11 12 …`

Auf einer 4-TB-GPT-Platte war die GPT früher an derselben Stelle (Sektor 33) beschädigt
worden, nachdem `smartctl -d jmb39x-q` auf Unraid lief.

## Folgerungen für tr004-smart

* Der Briefkasten ist nicht vermeidbar, aber der Sektor ist frei wählbar.
  Er muss außerhalb von MBR/GPT-Tabelle und Partitionen liegen.
* Weil auch andere Sektoren (Sektor 0) betroffen sein können, sichert das Werkzeug
  den gesamten Bereich vor der ersten Partition aller Platten im Gehäuse und stellt
  ihn nach jedem Befehl wieder her.
