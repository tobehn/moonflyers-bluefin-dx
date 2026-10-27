# shellcheck shell=sh
# Image-Default-Config für Starship (Bluefin initialisiert Starship in
# 90-bluefin-starship.sh). Nur setzen, wenn weder STARSHIP_CONFIG gesetzt ist
# noch eine eigene ~/.config/starship.toml existiert — ein bedingungsloses
# STARSHIP_CONFIG würde die User-Config überstimmen.
if [ -z "${STARSHIP_CONFIG:-}" ] && [ ! -e "${HOME}/.config/starship.toml" ]; then
  export STARSHIP_CONFIG=/usr/share/moonflyers/starship.toml
fi
