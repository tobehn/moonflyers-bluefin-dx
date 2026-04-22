# moonflyers-bluefin-dx

Personal Bluefin-DX Custom-Image für [moonflyer](https://github.com/tobehn) — meinen **Schenker Vision M23** (Tongfang PH6PG01 / NB02, baugleich zum [TUXEDO InfinityBook Pro 16 Gen8](https://www.tuxedocomputers.com/en/TUXEDO-InfinityBook-Pro-16-Gen8.tuxedo)).

**Base:** [`ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable`](https://github.com/ublue-os/bluefin)
**Registry:** `ghcr.io/tobehn/moonflyers-bluefin-dx:latest`
**Builds:** GitHub Actions daily (23:50 UTC) + on push

## Included customizations

| Feature | Purpose |
|---|---|
| **nvidia-open kernel driver** | dGPU (RTX 4060 Mobile) permanent am Host für PRIME Render Offload (FreeCAD, Blender, CUDA). Kein VM-Passthrough mehr. |
| **tuxedo-drivers** (upstream + Schenker-DMI-Patch) | Tuxedo Control Center volle Features: Fan Curves, Battery Care, TGP-Toggle, Keyboard-Backlight. Siehe [Patches](#patches). |
| **Looking Glass client B7** + kvmfr module | Infrastruktur für VM-Framebuffer-Passthrough (aktuell ungenutzt, vorgehalten falls Windows-CAD nötig wird). |
| **fixtuxedo.service** | `/opt`-Symlink-Workaround für TCC auf OSTree. |
| **LogiOps** (`logid.service`) | Erweiterte Logitech-MX-Master-Konfiguration, Gesten. |
| **spacenavd** | 3D-Maus-Support (SpaceMouse). |
| **ydotool** + `wtype`-Wrapper | Keyboard-Input-Automation auf Wayland (z.B. für soundvibes). |
| **rpiboot** (from source) | Raspberry Pi USB Boot Tool. |
| **LibrePods** (from source) | AirPods-Integration unter Linux. |
| **Utilities** | tmux, screen. |

## How to rebase

Auf einem bestehenden Bluefin-System:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/tobehn/moonflyers-bluefin-dx:latest
systemctl reboot
```

Für Updates reicht später:

```bash
rpm-ostree upgrade
systemctl reboot
```

Rollback bei Problemen:

```bash
rpm-ostree rollback
systemctl reboot
```

## Patches

Custom patches gegen Upstream-Sources liegen in [`build_files/patches/`](build_files/patches/) und werden in `build.sh` per `git apply` nach dem `git clone` angewendet.

| Patch | Betrifft | Grund |
|---|---|---|
| `0001-allow-schenker-dmi.patch` | `tuxedo-drivers` | Schenker Vision M23 ist hardware-identisch zum TUXEDO InfinityBook Pro 16 Gen8 (beide Tongfang PH6PG01/NB02), nur der DMI-Vendor unterscheidet sich. Upstream gatekeept Modul-Load auf `DMI_SYS_VENDOR = "TUXEDO"`, der CPU-Fallback greift auf Raptor Lake (13th Gen) nicht mehr. Patch forcet `tuxedo_is_compatible()` auf `return true`. |

## Secure Boot

**Aktuell: deaktiviert.** Die selbst-gebauten Tuxedo-Module sind nicht signiert, der Kernel lehnt sie sonst mit „Key was rejected by service" ab.

Modul-Signing ist geplant (X.509-Keypair, Public-Cert im Image, Private-Key als GitHub-Secret, `--mount=type=secret` im Build-Step, MOK-Enrollment via `mokutil --import`). Danach kann Secure Boot wieder aktiviert werden.

## Image signing (cosign)

Das Image selbst wird per cosign signiert (`cosign.pub` im Repo-Root, `SIGNING_SECRET` als GitHub-Secret). Verifikation durch User:

```bash
cosign verify --key cosign.pub ghcr.io/tobehn/moonflyers-bluefin-dx:latest
```

## Related

- [Machine-Notiz moonflyer](../../topics/administration/machines/moonflyer.md) (ai-vault) — Setup-Status, Hardware-Details, Akku-Management, TODOs
- [Upstream tuxedo-drivers](https://github.com/tuxedocomputers/tuxedo-drivers)
- [ublue-os/bluefin](https://github.com/ublue-os/bluefin) — Base-Image
- [TUXEDO InfinityBook Pro 16 Gen8](https://www.tuxedocomputers.com/en/TUXEDO-InfinityBook-Pro-16-Gen8.tuxedo) — baugleiche Referenz-Hardware

## Credits

Based on the [`ublue-os/image-template`](https://github.com/ublue-os/image-template) — huge thanks to the Universal Blue community for the bootc/OSTree infrastructure.
