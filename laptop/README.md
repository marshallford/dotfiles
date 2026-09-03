# Laptop Installation Guide

> Arch Linux, LUKS2 + Btrfs, Secure Boot with signed UKIs, Limine/Plymouth boot, greetd login, Niri/DMS Wayland desktop, PipeWire audio, NetworkManager, keyd macOS-style keys, Voxtype dictation, restic backups

Two NVMe disks: a 1TB SK hynix for Linux and a 256GB WD with a pre-existing Windows install. Kernel device names are not stable, so everything below addresses disks through `/dev/disk/by-id` or `by-label`. Only the SK hynix is repartitioned. Windows has no ESP of its own, so both bootloaders share the SK hynix ESP and Windows must be re-registered on it after the wipe (see [Clean up](#clean-up)).

## Within Windows

PowerShell as Administrator:

```powershell
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -PropertyType DWord -Value 0 -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name RealTimeIsUniversal -PropertyType DWord -Value 1 -Force
powercfg /h off
```

1. `HiberbootEnabled` disables Fast startup, which otherwise leaves NTFS hibernated on shutdown and unsafe to mount read-write
2. `RealTimeIsUniversal` matches the UTC hardware clock set by `hwclock --systohc` in [Within Arch Linux install media](#within-arch-linux-install-media)
3. `powercfg /h off` disables real hibernation, which dirties NTFS the same way

## Within BIOS

In the Dell BIOS (F2):

1. Boot Configuration -> Secure Boot -> Enable Secure Boot: Off. The Arch ISO is unsigned and will not boot otherwise; [Secure Boot](#secure-boot) re-enables it
2. Storage -> SATA/NVMe Operation: AHCI/NVMe, not RAID On. Intel RST otherwise hides the NVMe disks from the installer

## Within Arch Linux install media

1. Follow https://wiki.archlinux.org/title/Installation_guide through "Connect to the internet"
2. Follow https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH
3. Follow steps below (based on https://gist.github.com/yovko/512326b904d120f3280c163abfbcb787)

```shell
lsblk -o NAME,SIZE,MODEL # device names are not stable, identify the disk by model
DISK=/dev/disk/by-id/nvme-PC811_SED_SK_hynix_1024GB____AME9N00091080975E # 1TB SK hynix, not the WD
ls -l "$DISK" # confirm it resolves to the 1TB disk

sgdisk --zap-all "$DISK"

parted --script "$DISK" \
mklabel gpt \
mkpart ESP fat32 1MiB 4097MiB \
set 1 esp on \
mkpart Linux btrfs 4097MiB 100%

mkfs.fat -n ESP -F 32 "$DISK-part1"

cryptsetup luksFormat --label CRYPTROOT "$DISK-part2"

cryptsetup open "$DISK-part2" root
mkfs.btrfs -L ROOT /dev/mapper/root

mount /dev/mapper/root /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache

umount /mnt

mount -o compress=zstd:1,noatime,subvol=@ /dev/mapper/root /mnt
mount --mkdir -o compress=zstd:1,noatime,subvol=@home /dev/mapper/root /mnt/home
mount --mkdir -o compress=zstd:1,noatime,subvol=@var_log /dev/mapper/root /mnt/var/log
mount --mkdir -o compress=zstd:1,noatime,subvol=@var_cache /dev/mapper/root /mnt/var/cache
mount --mkdir "$DISK-part1" /mnt/boot

pacman -Syy
pacstrap -K /mnt base base-devel linux linux-lts linux-firmware sof-firmware intel-ucode wireless-regdb btrfs-progs ntfs-3g exfatprogs efibootmgr limine cryptsetup util-linux plymouth systemd-ukify sbctl openssh git nano reflector

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

DISK=/dev/disk/by-id/nvme-PC811_SED_SK_hynix_1024GB____AME9N00091080975E # chroot drops the outer shell

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

nano /etc/locale.gen # uncomment the UTF-8 locale 'en_US.UTF-8 UTF-8'
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

nano /etc/conf.d/wireless-regdom # uncomment the domain 'WIRELESS_REGDOM="US"'

echo dell > /etc/hostname

passwd

cryptsetup luksUUID /dev/disk/by-label/CRYPTROOT # copy uuid

nano /etc/mkinitcpio.conf # system/setup package
nano /etc/kernel/cmdline # system/setup package, paste uuid into rd.luks.name
nano /etc/mkinitcpio.d/linux.preset # system/setup package
nano /etc/mkinitcpio.d/linux-lts.preset # system/setup package
mkdir -p /boot/EFI/Linux
mkinitcpio -P

mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
nano /boot/EFI/limine/limine.conf # system/setup package

efibootmgr --create --disk "$(readlink -f "$DISK")" --part 1 --label "Arch Linux Limine Bootloader" --loader '\EFI\limine\BOOTX64.EFI' --unicode

ls /boot/EFI/Linux # must list both UKIs before leaving the chroot

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

## Secure Boot

Custom keys via `sbctl`, signing Limine and the UKIs so the firmware verifies each one. Signing happens before the firmware is touched, so Secure Boot is never enforced against an unsigned binary.

```shell
sbctl --disable-landlock export-enrolled-keys --dir /root/efi-keys-backup --format esl # PK deletion is irreversible, copy off machine
sbctl create-keys
sbctl sign -s /boot/EFI/limine/BOOTX64.EFI
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sbctl sign -s /boot/EFI/Linux/arch-linux-lts.efi
sbctl sign -s /usr/lib/fwupd/efi/fwupdx64.efi
sbctl verify # expect EFI/Microsoft, EFI/Boot and vmlinuz-* unsigned, leave them
```

In the Dell BIOS (F2):

1. Boot Configuration -> Secure Boot -> Enable Secure Boot: On, undoing [Within BIOS](#within-bios)
2. Boot Configuration -> Secure Boot -> Enable Microsoft UEFI CA: Enabled. Option ROMs need it and `--firmware-builtin` reads it out of `dbDefault`
3. Boot Configuration -> Expert Key Management -> Enable Custom Mode: On. This alone clears the PK and moves Secure Boot Mode from Deployed to Audit
4. Save and boot back into Arch. If `sbctl status` does not report Setup Mode enabled, return and delete the PK under Custom Mode Key Management

```shell
sbctl status # Setup Mode: Enabled
sbctl enroll-keys --microsoft --firmware-builtin db,KEK # if it reports immutable efivars, chattr -i the files it names and retry
reboot # confirm with sbctl status
```

If the firmware refuses to boot afterwards, turn Secure Boot back off in the BIOS and re-check `sbctl verify`.

Boot the Limine Windows entry once. It confirms the Microsoft certificates survived enrollment, which is the main risk of replacing the platform key on a shared ESP.

Nothing needs signing by hand afterwards: mkinitcpio's `sbctl` post hook signs each UKI as it is built, `zz-sbctl.hook` re-signs the database on package upgrades, and `99-limine.hook` signs `BOOTX64.EFI` when Limine is redeployed.

## Create user

```shell
useradd -s /bin/zsh -mG wheel input marshall
passwd marshall
EDITOR=nano visudo # uncomment "%wheel ALL=(ALL:ALL) ALL"
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
sudo mount -o ro /dev/disk/by-id/nvme-WD_PC_SN740_SDDQNQD-256G-1001_2330P1400623-part2 /mnt # Windows disk
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
2. Restore Windows UEFI entry, wiped along with the ESP: boot into Windows install media (Microsoft-signed, so Secure Boot can stay on), command prompt, `diskpart`, `select disk 0`, `select partition 1`, `assign letter=S`, `exit`, `bcdboot C:\Windows /s S: /f UEFI`. This writes `EFI/Microsoft` and `EFI/Boot/bootx64.efi`, which Limine's `/Windows` entry chainloads

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

## Recover the ESP

Windows shares the ESP, so its updates can reset the UEFI boot order or overwrite the ESP itself. Fix the order from Arch:

```shell
efibootmgr # find the Limine entry number
sudo efibootmgr -o 0002,0001,0000 # example numbers, Limine first
```

If the ESP itself was wiped, boot the Arch install media with Secure Boot off:

```shell
cryptsetup open /dev/disk/by-label/CRYPTROOT root
mount -o compress=zstd:1,noatime,subvol=@ /dev/mapper/root /mnt
mount --mkdir /dev/disk/by-label/ESP /mnt/boot
arch-chroot /mnt

DISK=/dev/disk/by-id/nvme-PC811_SED_SK_hynix_1024GB____AME9N00091080975E

mkdir -p /boot/EFI/Linux /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
nano /boot/EFI/limine/limine.conf # system/setup package
mkinitcpio -P # rebuilds and signs the UKIs
sbctl sign-all # the sbctl database survives on @, so this re-signs BOOTX64.EFI and fwupd
sbctl verify

efibootmgr # NVRAM entries usually survive an ESP wipe, only re-create if missing
efibootmgr --create --disk "$(readlink -f "$DISK")" --part 1 --label "Arch Linux Limine Bootloader" --loader '\EFI\limine\BOOTX64.EFI' --unicode

exit
umount -R /mnt
cryptsetup close root
reboot # re-enable Secure Boot, then Clean up step 2 if EFI/Microsoft was lost too
```

## TODO

1. Network printing: `cups` (pulls avahi, cups-filters), hand mDNS from resolved to avahi via `nss-mdns` + `nsswitch.conf`
