# tr004-smart

SMART-Werte (Temperatur, Gesundheit, Sektorfehler) von Festplatten im **QNAP TR-004**
unter **Unraid/Linux** auslesen – ohne die Partitionstabellen zu zerstören.

> **Status: experimentell.** Die Sicherheitslogik ist mit simulierten Platten getestet
> (`tests/run-tests.sh`) und lief am 15.11.2026 erfolgreich an einem echten TR-004 unter
> Unraid 7 (smartctl 7.5, Seagate 4 TB GPT + WD 1 TB MBR): Werte gelesen, Sektoren 0–63
> danach bitgenau unverändert. Nutzung auf eigenes Risiko.

## Das Problem

Der TR-004 (JMicron-RAID-Chip, USB `1c04:e014`) reicht SMART-Befehle nicht per USB durch.
Es gibt nur einen Weg, und den benutzt auch die QNAP-Software („External RAID Manager"):
einen **Briefkasten-Sektor**. Ein Befehlspaket (Kennung `0x197B0325`) wird in einen Sektor
einer Platte im Gehäuse geschrieben, der Chip antwortet über denselben Sektor.
`smartctl -d jmb39x-q,N` macht genau das, standardmäßig über **Sektor 33**.

Sektor 33 ist bei GPT-Platten der letzte Sektor der Partitionstabelle. Bleibt dort ein
Paket liegen (Abbruch, Zeitüberschreitung, USB-Reset), ist die GPT kaputt. In der Praxis
haben wir außerdem Platten gesehen, deren Sektor 0 (MBR) danach leer war.
Siehe [docs/befunde.md](docs/befunde.md).

## Was tr004-smart anders macht

1. **Nie Sektor 33.** Der Briefkasten liegt in der Lücke vor der ersten Partition
   (Standard: Sektor 48). Unraid legt Partitionen immer ab Sektor 64 an, egal ob MBR oder GPT.
2. **Vorher prüfen:** Partitionstabelle lesen, Briefkasten muss außerhalb von Tabelle und
   Partition liegen und leer sein. Sonst wird abgebrochen.
3. **Abbild und Wiederherstellung:** Vor dem Lauf werden die Sektoren 0–63 **aller**
   TR-004-Platten gesichert. Nach **jedem einzelnen** Befehl wird verglichen, und jeder
   veränderte Sektor wird sofort zurückgeschrieben und nachgeprüft. Das passiert auch bei
   Abbruch (Strg+C, kill).
4. **Ein Lauf gleichzeitig** (Sperre), abschaltbar, mit Protokoll in syslog.
5. **Erst freischalten:** `read` funktioniert erst nach `tr004-smart enable`, und das geht nur,
   wenn die Prüfung bestanden ist.

## Installation (Unraid)

```bash
mkdir -p /boot/config/custom
wget -O /boot/config/custom/tr004-smart https://raw.githubusercontent.com/2pac1991/tr004-smart/main/tr004-smart
chmod +x /boot/config/custom/tr004-smart
```

Der Unraid-USB-Stick erlaubt keine direkte Ausführung, daher immer mit `bash` aufrufen:
`bash /boot/config/custom/tr004-smart list`

Voraussetzungen: `smartctl` ab 7.3 (mit `jmb39x-q`), `jq`, `flock`. Bei Unraid ist das dabei.

## Benutzung

```bash
tr004-smart list            # Platten anzeigen und prüfen – schreibt nichts
tr004-smart enable          # echtes Auslesen freischalten (nur wenn die Prüfung OK ist)
tr004-smart read            # SMART aller Einschübe lesen
tr004-smart read --json     # dasselbe als JSON (auch in /var/lib/tr004-smart/last.json)
tr004-smart restore <dir>   # Sektoren aus einem gespeicherten Abbild zurückschreiben
```

Einstellungen in `/boot/config/tr004-smart.conf`, zum Beispiel:

```bash
TR004_MAILBOX_LBA=48     # Briefkasten-Sektor (muss < 64 und außerhalb der Tabelle sein)
TR004_PORTS="0 1 2 3"    # Einschübe
```

Abbilder liegen in `/var/lib/tr004-smart/snap-*` (die letzten 20 bleiben).

## Werte in der Unraid-Oberfläche

Unraid fragt SMART selbst mit `smartctl` ab. Damit es dabei nie den TR-004 direkt anspricht,
installiert `unraid/install.sh` einen **smartctl-Vermittler** (`unraid/smartctl-wrapper`):

* Für TR-004-Platten liefert er die zuletzt von `tr004-smart read` gelesene Ausgabe
  (Temperatur, Gesundheit, Attribute, alles wie gewohnt in Main/Dashboard).
* `jmb39x`/`jms56x`-Aufrufe ohne eigenen Briefkasten-Sektor werden **blockiert**.
* Alle anderen Platten gehen unverändert an das echte smartctl (`/usr/sbin/smartctl.real`).

```bash
cp unraid/smartctl-wrapper /boot/config/custom/smartctl-tr004-wrapper
cp unraid/install.sh /boot/config/custom/tr004-install.sh
echo 'bash /boot/config/custom/tr004-install.sh' >> /boot/config/go      # nach jedem Start
cp unraid/tr004-smart.cron /boot/config/plugins/dynamix/ && /usr/local/sbin/update_cron
```

## Unraid und Home Assistant

Siehe [unraid/](unraid/): ein Cron-Eintrag, der alle 10 Minuten liest, und ein Beispiel,
wie die Temperaturen in ein Home-Assistant-Webhook-Skript kommen.
Öfter als alle 10 Minuten abzufragen bringt nichts.

## Wichtig

* **Die QNAP-Software nicht gleichzeitig benutzen.** Sie verwendet dieselbe Methode
  (auch mit Sektor 33) und kann mit Unraid-Platten genauso Schaden anrichten.
* `smartctl -d jmb39x-q` **nie direkt** auf Unraid-Platten ausführen.
* Beschädigte Partitionstabelle? Siehe [docs/reparatur.md](docs/reparatur.md).

## Tests

```bash
bash tests/run-tests.sh
```

Die Tests simulieren GPT- und MBR-Platten und einen smartctl, der absichtlich Sektor 0
und den Briefkasten überschreibt. Sie laufen auch unter macOS.

## Lizenz

MIT – siehe [LICENSE](LICENSE). Kein Code von QNAP oder JMicron enthalten;
die Befunde in `docs/` beruhen auf eigener Analyse zur Herstellung von Interoperabilität.
