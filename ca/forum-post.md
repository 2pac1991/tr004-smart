**Title:** [Plugin] TR-004 SMART – safe SMART data for disks in a QNAP TR-004 (Beta)

---

**TR-004 SMART** shows the SMART data of disks inside a **QNAP TR-004** USB enclosure in the Unraid GUI – temperature, health, all attributes, identity and error log – as if the disks were attached directly.

**Why this plugin exists**

The TR-004's JMicron controller does not pass SMART commands through USB. The only way to talk to the disks is a "mailbox" sector: a command packet is written to a sector of one of the enclosure's disks and the controller answers through the same sector. `smartctl -d jmb39x-q,N` does exactly that – by default with **sector 33**, which on GPT disks is part of the partition table. If a request is interrupted, the packet stays on the disk and the GPT is corrupted. I lost the partition tables of two array disks this way (data was intact and could be recovered). QNAP's own "External RAID Manager" uses the same method.

**What the plugin does**

- Uses a free sector in the gap before the first partition (default 48; Unraid always starts partitions at sector 64) – never sector 33
- Checks the partition layout first and refuses to run if the mailbox sector is not provably unused
- Backs up sectors 0–63 of **every** enclosure disk before each run and compares/restores them after **every single command**, also on abort
- Installs a `smartctl` wrapper: Unraid gets the TR-004 values from the last safe read, everything else goes to the real smartctl, and unsafe `jmb39x`/`jms56x` calls without an own mailbox sector are **blocked** system-wide
- Health and attributes every minute, full report (`-x`) every hour, self-test buttons in the GUI work
- Settings page under *Settings → Utilities → TR-004 SMART* (English/German), command line `tr004-smart`
- Reading has to be enabled explicitly after the safety check passed

**Limitations**

- The JMB39x cannot pass 48-bit ATA log commands: self-test log, SCT temperature history and device statistics are not available
- The device name in Unraid stays `QNAP_TR-004_DISKxx`
- Tested so far on one TR-004 with Unraid 7 / smartctl 7.5 (Seagate IronWolf 4 TB GPT, WD Blue 1 TB MBR). **This is a beta – feedback from other TR-004 owners is very welcome.**

**Install:** Plugins → Install Plugin →
`https://raw.githubusercontent.com/2pac1991/tr004-smart/main/plugin/tr004-smart.plg`

**Source, details and findings:** https://github.com/2pac1991/tr004-smart

Please post problems here or as a GitHub issue, ideally with the output of `tr004-smart list`.
