# Dotfiles

Per-machine configuration, managed with [GNU Stow](https://www.gnu.org/software/stow/).

* [Laptop](./laptop) - Arch Linux, Niri/DMS Wayland desktop

## Layout

* `<machine>/home/<pkg>` - stowed to `~`
* `<machine>/system/<pkg>` - stowed to `/`
* `<machine>/system/setup` - copied by hand; config that cannot be a symlink into `/home` (early boot, sandboxed or symlink-averse consumers, vfat `/boot`, pre-clone install steps)

`make lint` runs editorconfig, shellcheck, and yamllint.
