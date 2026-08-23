# Laptop Installation Guide

> Arch Linux, LUKS2 + Btrfs, Limine/Plymouth boot, greetd login, Niri/DMS Wayland desktop, PipeWire audio, NetworkManager, keyd macOS-style keys, Voxtype dictation, restic backups

## Within Arch Linux install media

1. Follow https://wiki.archlinux.org/title/Installation_guide through "Connect to the internet"
2. Follow https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH
3. Follow steps below (based on https://gist.github.com/yovko/512326b904d120f3280c163abfbcb787)

```shell
fdisk -l # ensure nvme0n1 is the correct disk

sgdisk --zap-all /dev/nvme0n1

parted --script /dev/nvme0n1 \
mklabel gpt \
mkpart ESP fat32 1MiB 4097MiB \
set 1 esp on \
mkpart Linux btrfs 4097MiB 100%

mkfs.fat -n ESP -F 32 /dev/nvme0n1p1

cryptsetup luksFormat --label CRYPTROOT /dev/nvme0n1p2

cryptsetup open /dev/nvme0n1p2 root
mkfs.btrfs -L ROOT /dev/mapper/root

mount /dev/mapper/root /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@snapshots

umount /mnt

mount -o compress=zstd:1,noatime,subvol=@ /dev/mapper/root /mnt
mount --mkdir -o compress=zstd:1,noatime,subvol=@home /dev/mapper/root /mnt/home
mount --mkdir -o compress=zstd:1,noatime,subvol=@var_log /dev/mapper/root /mnt/var/log
mount --mkdir -o compress=zstd:1,noatime,subvol=@var_cache /dev/mapper/root /mnt/var/cache
mount --mkdir -o compress=zstd:1,noatime,subvol=@snapshots /dev/mapper/root /mnt/.snapshots
mount --mkdir /dev/nvme0n1p1 /mnt/boot

pacman -Syy
pacstrap -K /mnt base base-devel linux linux-lts linux-firmware sof-firmware intel-ucode wireless-regdb btrfs-progs ntfs-3g exfatprogs efibootmgr limine cryptsetup util-linux plymouth openssh git nano reflector

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

nano /etc/locale.gen # Uncomment the UTF-8 locales you will be using, example: 'en_US.UTF-8 UTF-8'
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

nano /etc/conf.d/wireless-regdom # Uncomment the appropriate domain, example: 'WIRELESS_REGDOM="US"'

echo dell > /etc/hostname

passwd

nano /etc/mkinitcpio.conf # system/setup package
mkinitcpio -P

mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/

efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Linux Limine Bootloader" --loader '\EFI\limine\BOOTX64.EFI' --unicode

cryptsetup luksUUID /dev/nvme0n1p2 # copy uuid
nano /boot/EFI/limine/limine.conf # system/setup package

exit
umount -R /mnt
cryptsetup close root
reboot
```

## After reboot networking

1. `systemctl enable --now systemd-networkd systemd-resolved`
2. `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`
3. `nano /etc/systemd/network/20-wired.network` # https://wiki.archlinux.org/title/Systemd-networkd#Wired_adapter_using_DHCP
4. `systemctl restart systemd-networkd systemd-resolved`
5. Follow https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH
6. `systemctl disable systemd-networkd-wait-online.service`
7. `systemctl mask systemd-networkd-wait-online.service`

## After reboot setup

```shell
nano /etc/pacman.conf # system/setup package
mkdir -p /etc/pacman.d/hooks
nano /etc/pacman.d/hooks/99-limine.hook # system/setup package
nano /etc/xdg/reflector/reflector.conf # system/setup package
mkdir -p /etc/systemd/system/reflector.service.d
nano /etc/systemd/system/reflector.service.d/retry.conf # system/setup package
systemctl enable reflector.timer
systemctl start reflector
pacman -Sy intel-media-driver vpl-gpu-rt mesa vulkan-intel
pacman -Sy vim less wget btop htop zip unzip zsh fwupd udisks2 usbutils stow kernel-modules-hook
fwupdmgr get-devices
fwupdmgr refresh
fwupdmgr get-updates
fwupdmgr update
systemctl enable --now fwupd-refresh.timer
systemctl enable --now fstrim.timer
systemctl enable --now linux-modules-cleanup.service
```

## Create user

```shell
useradd -s /bin/zsh -mG wheel input marshall
passwd marshall
EDITOR=nano visudo # Uncomment "%wheel ALL=(ALL:ALL) ALL"
reboot # to avoid PAM issues, at the very least logout and connect/login as marshall
```

## Clone dotfiles

```shell
mkdir -p ~/Documents/Projects
git clone https://github.com/marshallford/dotfiles.git ~/Documents/Projects/dotfiles # https for bootstrap, see Restore
```

## Install yay

```shell
stow -d ~/Documents/Projects/dotfiles/laptop/home -t ~ pacman
cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
cd ~ && rm -rf yay
```

## Fonts

```shell
yay -Sy noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono-nerd
```

Windows fonts

```shell
yay -Sy ttf-ms-win11 # should fail
sudo mount /dev/nvme1n1p2 /mnt
cp /mnt/Windows/{Fonts/*.{ttf,ttc},System32/Licenses/neutral/*/*/license.rtf} ~/.cache/yay/ttf-ms-win11/
yay -S ttf-ms-win11
sudo umount /mnt
rm -rf ~/.cache/yay/ttf-ms-win11
```

## Audio

```shell
yay -Sy wireplumber pipewire pipewire-alsa pipewire-jack pipewire-pulse
```

## Network

```shell
yay -Sy networkmanager
sudo systemctl disable --now systemd-networkd
sudo rm /etc/systemd/network/20-wired.network
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
systemctl --user enable --now ssh-agent.socket
```

## System tuning

```shell
yay -Sy zram-generator thermald
cd ~/Documents/Projects/dotfiles/laptop/system/setup
sudo cp -r etc/systemd/{zram-generator.conf.d,oomd.conf.d,system.conf.d,user} /etc/systemd/
sudo cp -r etc/{sysctl.d,tmpfiles.d} /etc/
sudo systemctl enable thermald systemd-oomd
```

## Devices

```shell
cd ~/Documents/Projects/dotfiles/laptop/system/setup
sudo cp -r etc/{udev,modprobe.d} /etc/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Keyboard (keyd)

```shell
yay -Sy keyd
cd ~/Documents/Projects/dotfiles/laptop/system/setup
sudo cp -r etc/keyd /etc/
sudo keyd check
sudo systemctl enable --now keyd
```

## Voice-to-Text (voxtype)

```shell
yay -Sy voxtype-bin
sudo voxtype setup gpu --enable
voxtype setup --download --model large-v3-turbo
rm ~/.config/voxtype/config.toml # generated by setup, swap for dotfiles
systemctl --user enable --now voxtype.service
voxtype setup check
```

## Shell/DE

```shell
yay -Sy dms-shell-niri nautilus xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring xwayland-satellite libappindicator wl-clipboard cava i2c-tools matugen power-profiles-daemon qt6-multimedia-ffmpeg qt6ct wtype adw-gtk-theme cups-pk-helper kimageformats
systemctl --user add-wants niri.service dms
dms setup # may need to `rm -rf ~/.config/niri` first
```

## Display/Login Manager

```shell
yay -Sy greetd-dms-greeter-bin
cd ~/Documents/Projects/dotfiles/laptop/system/setup
sudo cp -r etc/{greetd,pam.d} /etc/
sudo systemctl enable --now greetd
dms greeter sync # adds ${USER} to the greeter group
```

## CLI Applications

```shell
yay -Sy ethtool wavemon nmap pacman-contrib rsync ripgrep jq yq zsh-antidote zsh-pure-prompt restic github-cli kubectl kubelogin kustomize helm k9s aws-cli-v2 fluxcd sops tfenv rustup nvm go uv bats docker docker-compose podman kind istio cilium-cli
sudo usermod -aG tfenv ${USER}
sudo systemctl enable --now docker.socket
sudo usermod -aG docker ${USER}
sudo systemctl enable --now paccache.timer
# logout
```

## Desktop applications

```shell
yay -Sy vlc vlc-plugins-all chromium ghostty visual-studio-code-bin spotify-launcher slack-desktop discord loupe file-roller baobab seahorse gnome-calculator
```

## Clean up

1. SSH: `PermitRootLogin prohibit-password` and `systemctl disable --now sshd`
2. Restore Windows UEFI entry: Boot into Windows install media, command prompt, `diskpart`, `select disk 0`, `select partition 1`, `assign letter=S`, `exit`, `bcdboot C:\Windows /s S: /f UEFI`

## Dotfiles

```shell
cd ~/Documents/Projects/dotfiles # root of dotfiles repository
cd laptop # machine
sudo stow --no-folding -d system -t / docker podman restic-backup
stow --no-folding -d home -t ~ chromium desktop-applications dms ghostty git niri pacman ssh terraform voxtype vscode xdg-defaults zsh
```

## Restore

1. Restic: see [system/restic-backup](./system/restic-backup/README.md) for repo init, credentials, and NAS key
2. Restoring `/home/marshall` recovers `~/.ssh/{github,primary-lan}`
3. Dotfiles remote: `git -C ~/Documents/Projects/dotfiles remote set-url origin git@github.com:marshallford/dotfiles.git`

## TODO

1. Network printing: `cups` (pulls avahi, cups-filters), hand mDNS from resolved to avahi via `nss-mdns` + `nsswitch.conf`
