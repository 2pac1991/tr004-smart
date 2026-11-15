# Temperaturen an Home Assistant schicken

`tr004-smart read` legt das Ergebnis in `/var/lib/tr004-smart/last.json` ab, zum Beispiel:

```json
[{"port":0,"model":"ST4000VN008","serial":"ZDH...","passed":true,"temp":34,"power_on_hours":21000,"realloc":0,"pending":0,"offline_unc":0}]
```

Ein Statistik-Skript, das ohnehin regelmäßig an einen HA-Webhook sendet, liest einfach die Datei
(nie selbst smartctl aufrufen):

```bash
J=/var/lib/tr004-smart/last.json
t() { jq -r --argjson p "$1" '.[] | select(.port==$p) | .temp // 0' "$J" 2>/dev/null || echo 0; }
DISK1_TEMP=$(t 0); DISK2_TEMP=$(t 1); DISK3_TEMP=$(t 2)
```

Für Warnungen eignen sich `passed`, `realloc`, `pending` und `offline_unc`
(alles über 0 bei den letzten drei ist ein Grund, die Platte im Auge zu behalten).
