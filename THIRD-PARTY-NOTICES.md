# Third-party notices

Mac DFU Studio is proprietary software (see [LICENSE](LICENSE)). One part of it is derived from
third-party work and stays under that work's own license.

## AppleHPMLib interface definitions

The layout of the `AppleHPMLib` plug-in interface, its interface UUIDs, and the sequence of commands
used to send a USB-PD vendor message through the port controller — in
[`Sources/CHPMBridge/CHPMBridge.c`](Sources/CHPMBridge/CHPMBridge.c) — are derived from:

- **macvdmtool** — Copyright The Asahi Linux Contributors
  <https://github.com/AsahiLinux/macvdmtool>
- **ThunderboltPatcher** — Copyright osy
  <https://github.com/osy/ThunderboltPatcher>

Both are licensed under the Apache License, Version 2.0. A copy of that license is in
[`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt). The derived portions have been modified:
rewritten as a C bridge with a different API, with added port discovery, error reporting and the
Intel T2 fallback.

## Research this app builds on

These projects are not included in the app; their published findings informed it.

- **restorekit** by fcjr — the VDM that puts an Intel T2 Mac into DFU, and how a running Mac
  identifies itself over USB. <https://github.com/fcjr/restorekit>
- **DFU-Pulse** by BartoX360 and **target-mac-dfu** by SampsiH — examples of driving `cfgutil`.

## Apple documentation followed

- [How to revive or restore Mac firmware](https://support.apple.com/108900)
- [Identify the DFU port on a Mac](https://support.apple.com/120694)
- Mac User Guide: *Transfer files between two Mac computers using target disk mode*, and
  *Use Share Disk to transfer files between two Mac computers*
