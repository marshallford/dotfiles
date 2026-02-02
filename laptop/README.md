# Laptop Installation Guide

> Arch Linux, LUKS, BTRFS, Limine, Plymouth, Greetd, NetworkManager, Pipewire, Niri, DMS

## Within Arch Linux install media

1. Follow https://wiki.archlinux.org/title/Installation_guide through "Connect to the internet"
2. Follow https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH
3. Follow steps below (based on https://gist.github.com/yovko/512326b904d120f3280c163abfbcb787)

```
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
pacstrap -K /mnt base base-devel linux linux-firmware sof-firmware intel-ucode btrfs-progs ntfs-3g exfatprogs efibootmgr limine cryptsetup util-linux plymouth openssh rsync git nano reflector

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

nano /etc/locale.gen # Uncomment the UTF-8 locales you will be using, example: "en_US.UTF-8 UTF-8"
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

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

```
mkdir -p /etc/pacman.d/hooks
nano /etc/pacman.d/hooks/99-limine.hook # system/setup package
echo "--save /etc/pacman.d/mirrorlist --protocol https --age 2 --fastest 5 --number 10 --sort rate --ipv4" > /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer
systemctl start reflector
pacman -Syu intel-media-driver mesa vulkan-intel
pacman -Syu vim less wget btop htop zip unzip zsh fwupd udisks2 usbutils stow
fwupdmgr get-devices
fwupdmgr refresh
fwupdmgr get-updates
fwupdmgr update
systemctl enable --now fwupd-refresh.timer
systemctl enable --now fstrim.timer
```

## Create user

```
useradd -s /bin/zsh -mG wheel marshall
passwd marshall
EDITOR=nano visudo # Uncomment "%wheel ALL=(ALL:ALL) ALL"
reboot # to avoid PAM issues, at the very least logout and connect/login as marshall
```

## Install yay

```
cd ~
mkdir -p .config/pacman
nano .config/pacman/makepkg.conf # home/pacman package
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
cd ~ && rm -rf yay
```

## Fonts

```
yay -Syu noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono-nerd
```

Windows fonts

```
yay -Syu ttf-ms-win11 # should fail
sudo mount /dev/nvme1n1p2 /mnt
cp /mnt/Windows/{Fonts/*.{ttf,ttc},System32/Licenses/neutral/*/*/license.rtf} ~/.cache/yay/ttf-ms-win11/
yay -S ttf-ms-win11
sudo umount /mnt
rm -rf ~/.cache/yay/ttf-ms-win11
```

## Audio

```
yay -Syu wireplumber pipewire pipewire-alsa pipewire-jack pipewire-pulse
```

## Network

```
yay -Syu networkmanager
sudo systemctl disable --now systemd-networkd
sudo rm /etc/systemd/network/20-wired.network
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluestooth
systemctl --user enable --now ssh-agent.service
```

## Shell/DE

```
yay -Syu niri uwsm nautilus xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring xwayland-satellite libappindicator wl-clipboard
yay -Syu dms-shell-bin accountsservice dgop-bin quickshell-git cava i2c-tools matugen power-profiles-daemon qt6-multimedia-ffmpeg qt6ct adw-gtk-theme
systemctl --user add-wants niri.service dms
dms setup # may need to `rm -rf ~/.config/niri` first
```


## Display/Login Manager

```
yay -Syu greetd greetd-dms-greeter-git
sudo nano /etc/greetd/config.toml # system/setup package
sudo nano /etc/pam.d/greetd # system/setup package
sudo nano /etc/pam.d/passwd # system/setup package
sudo systemctl enable --now greetd
dms greeter sync
```

## CLI Applications

```
yay -Syu jq yq zsh-antidote zsh-pure-prompt restic github-cli kubectl kubelogin kustomize helm k9s aws-cli-v2 fluxcd sops tfenv nvm go docker podman
sudo usermod -aG tfenv ${USER}
sudo systemctl enable --now docker.socket
sudo usermod -aG docker ${USER}
# logout
```

## Desktop applications

```
yay -Syu vlc vlc-plugins-all chromium ghostty visual-studio-code-bin spotify-launcher slack-desktop discord loupe file-roller baobab seahorse
```

## Clean up

1. SSH: `PermitRootLogin prohibit-password` and `systemctl disable --now sshd`
2. Restore Windows UEFI entry: Boot into Windows install media, command prompt, `diskpart`, `select disk 0`, `select partition 1`, `assign letter=S`, `exit`, `bcdboot C:\Windows /s S: /f UEFI`

## Dotfiles

```
cd ~/Documents/dotfiles # root of dotfiles repository
cd laptop # machine
sudo stow -d system -t / podman
stow -d home -t ~ chromium desktop-applications dms ghostty git niri pacman ssh terraform vscode zsh
```

## TODO

1. Misc networking: mDNS, Avahi, CUPS
2. Restic backups, Backblaze?
3. UWSM configuration in DMS
4. Restore GPG keys
5. Git switch and restore
6. AWS configuration
7. Correct editorconfig file in other repositories
