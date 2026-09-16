# Dotfiles

Per-machine configuration, managed with [GNU Stow](https://www.gnu.org/software/stow/).

* [Personal Dell](./personal-dell) - Arch Linux, Niri/DMS Wayland desktop
* [Work MacBook](./work-macbook) - macOS, Apple Silicon

## Layout

* `shared/home/<pkg>` - stowed to `~`
* `<machine>/home/<pkg>` - stowed to `~`
* `<machine>/system/<pkg>` - stowed to `/`
* `<machine>/system/setup` - copied by hand; config that cannot be a symlink into `/home` (early boot, sandboxed or symlink-averse consumers, vfat `/boot`, pre-clone install steps)

A machine stows the shared packages it wants alongside its own. Shared holds the base config and the machine overrides it through the optional file each format already looks for - `config.local`, `.zshrc.local`, an `Include` fragment, an `[include]` path - which is ignored when absent.

`make lint` runs editorconfig, shellcheck, and yamllint.
