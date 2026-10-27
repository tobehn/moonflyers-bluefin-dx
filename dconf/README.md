# dconf-Exports (opinionated GNOME-Settings)

Textuelle Sicherung persönlicher GNOME-Settings, die **nicht** aus dem Image
kommen. Zweck: auf einem neuen Rechner in Sekunden den vertrauten Zustand
herstellen, ohne die Binärdatei `~/.config/dconf/user` zu restaurieren
(die enthält *alle* Settings und lässt sich nicht selektiv einspielen).

## Wiederherstellen

```bash
dconf load /org/gnome/shell/extensions/tilingshell/ < dconf/tilingshell.dconf
```

Wirkt sofort, kein Logout nötig. Voraussetzung: die Extension ist installiert
(Tiling Shell, extensions.gnome.org ID **7065**) — `dconf load` schreibt nur
Werte, es installiert nichts.

## Aktualisieren (nach Setting-Änderungen in der GUI)

```bash
dconf dump /org/gnome/shell/extensions/tilingshell/ > dconf/tilingshell.dconf
```

## Was in `tilingshell.dconf` steckt

- **Keybindings** (Neo-Block `<Control><Super>` + `l/o/p/ä/ö`, span-/focus-/move-window)
- **Layouts** als `layouts-json`, u. a. das Custom-Layout `Drittel`
  (3 exakt gleiche Spalten für den Dell U4025QW, 5120×2160)
- **Gaps** (inner 4, outer 2), `edge-tiling-mode='granular'`, Autotiling an
- `overridden-settings` — Tiling Shell merkt sich hier die von ihm
  überschriebenen Mutter-/WM-Keybindings (`toggle-tiled-left/right` geleert,
  `maximize`/`unmaximize` auf `<Super>Up/Down`). **Mit einspielen**, sonst
  kann die Extension beim Deaktivieren die Originalwerte nicht zurückgeben.

## Maschinenabhängige Werte

`selected-layouts` ist ein Array pro *Monitor × Workspace*. Auf einem Rechner mit
anderer Monitor-Anzahl passt die Zuordnung nicht und wird im Panel-Menü neu
gewählt — schadet aber nicht. `last-version-name-installed` ist reiner Zustand.

## Systemweit ins Image backen (optional)

Statt per User-`dconf load` kann der Inhalt als Default für alle User in
`/etc/dconf/db/local.d/` landen (siehe `build_files/build.sh`, Muster wie beim
uupd-indicator: Datei schreiben + `dconf update`). Defaults greifen nur, solange
der User keinen eigenen Wert gesetzt hat — der bleibt also anpassbar.
