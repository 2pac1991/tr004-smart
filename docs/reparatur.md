# Reparatur einer beschädigten Partitionstabelle (Unraid)

Erst **lesen**, dann reparieren. Array vorher stoppen. Alle Befehle als root auf dem Unraid-Server.

## 1. Lage prüfen (schreibt nichts)

```bash
DEV=/dev/sdX                     # die betroffene Platte
dd if=$DEV bs=512 count=64 2>/dev/null | xxd | head -40
dd if=$DEV bs=512 skip=64 count=1 2>/dev/null | head -c 4; echo   # muss "XFSB" zeigen
blockdev --getsz $DEV            # Größe in Sektoren
```

## 2a. MBR fehlt (Platten bis 2 TB, Unraid-Layout: eine Partition ab Sektor 64)

Nur wenn ab Sektor 64 `XFSB` steht:

```bash
dd if=$DEV bs=512 count=64 of=/boot/config/vor-reparatur-$(basename $DEV).bin   # Sicherung
SZ=$(blockdev --getsz $DEV)
echo "64,$((SZ-64)),83" | sfdisk --no-reread --no-tell-kernel -X dos $DEV
partprobe $DEV
```

## 2b. GPT beschädigt (Platten über 2 TB)

GPT hat eine Sicherungskopie am Ende der Platte. Mit `gdisk` aus der Sicherung wiederherstellen:

```bash
dd if=$DEV bs=512 count=64 of=/boot/config/vor-reparatur-$(basename $DEV).bin   # Sicherung
printf "r\nc\nY\nw\nY\n" | gdisk $DEV
```

## 3. Prüfen

```bash
lsblk $DEV
xfs_repair -n ${DEV}1            # nur prüfen, schreibt nichts
```

Danach Array starten. Die Platte sollte normal erscheinen.
