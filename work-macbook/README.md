# Work MacBook Installation Guide

> macOS, Apple Silicon, Homebrew, Ghostty, Colima containers

## Bootstrap

```shell
xcode-select --install
```

Install Homebrew from the `.pkg` attached to the latest [release](https://github.com/Homebrew/brew/releases). Everything else, casks included, comes from the Brewfile.

## Clone dotfiles

```shell
mkdir -p ~/Documents/Projects
git clone https://github.com/marshallford/dotfiles.git ~/Documents/Projects/dotfiles # https for bootstrap, see Dotfiles remote
```

## Packages

```shell
cd ~/Documents/Projects/dotfiles # root of dotfiles repository
brew bundle install --file=work-macbook/Brewfile
brew bundle check --file=work-macbook/Brewfile # should report everything satisfied
```

`brew bundle cleanup --file=work-macbook/Brewfile` lists anything installed but not declared; add `--force` to remove it.

## macOS preferences

```shell
~/Documents/Projects/dotfiles/work-macbook/defaults.sh
```

Log out and back in afterwards. This machine is MDM enrolled, and `/Library/Managed Preferences` silently outranks anything written here; `ls /Library/Managed\ Preferences/*.plist` shows what MDM controls.

## Containers

Colima runs the Linux VM that backs the `docker` CLI:

```shell
colima start --cpu 4 --memory 8 --disk 60 --ssh-config=false
```

`--ssh-config=false` stops Colima from writing `~/.ssh/config`, which would otherwise exist as a regular file and make the later stow abort.

Colima supplies the daemon only. `buildx` and `compose` are client-side CLI plugins that Homebrew installs outside the path Docker searches:

```shell
mkdir -p ~/.docker/cli-plugins
ln -sfn /opt/homebrew/lib/docker/cli-plugins/docker-buildx ~/.docker/cli-plugins/
ln -sfn /opt/homebrew/lib/docker/cli-plugins/docker-compose ~/.docker/cli-plugins/
docker buildx version && docker compose version
```

## SSH keys

This machine needs `~/.ssh/{github,github-signing}`:

```shell
ssh-keygen -t ed25519 -C "marshall@work-macbook" -f ~/.ssh/github
ssh-keygen -t ed25519 -C "marshall@work-macbook" -f ~/.ssh/github-signing
ssh-add --apple-use-keychain ~/.ssh/github ~/.ssh/github-signing
```

Add the public halves to GitHub, `github` as an authentication key and `github-signing` as a signing key. Append the signing key to [allowed-signers](../shared/home/git-personal/.config/git/allowed-signers) under a comment naming this machine, otherwise commits signed here will not verify:

```shell
printf '# work-macbook\ninbox@marshallford.me namespaces="git" %s\n' "$(cut -d' ' -f1,2 ~/.ssh/github-signing.pub)" >> ~/Documents/Projects/dotfiles/shared/home/git-personal/.config/git/allowed-signers
ssh -T git@github.com
```

## Dotfiles

VS Code writes `settings.json` and `argv.json` on first launch, so both exist as regular files and stow aborts the whole invocation rather than replace them. Remove them first.

```shell
rm -f ~/.vscode/argv.json ~/Library/Application\ Support/Code/User/settings.json
```

```shell
cd ~/Documents/Projects/dotfiles # root of dotfiles repository
stow --no-folding -d shared/home -t ~ ghostty git git-personal ssh ssh-personal zsh
stow --no-folding -d work-macbook/home -t ~ ghostty git ssh terraform vscode zsh
```

## Secrets

Secrets live in `~/.zshenv.private`. The shared [.zshenv](../shared/home/zsh/.zshenv) sources it last, so it overrides everything above. The file below is created by hand from the stowed `.example` template.

```shell
cp ~/.zshenv.private.example ~/.zshenv.private
chmod 600 ~/.zshenv.private
```

## VS Code

```shell
import-vscode-extensions
```

## Dotfiles remote

```shell
git -C ~/Documents/Projects/dotfiles remote set-url origin git@github.com:marshallford/dotfiles.git
```

## Client work

Client repos live in `~/Documents/Work/<client>/`. The shared git config includes `~/.config/git/work` for that tree, and a repo there with no matching client refuses to commit. The files below are created by hand from the stowed `.example` templates.

```shell
cd ~/.config/git
cp work.example work # one includeIf block per client
cp work-CLIENT.example work-<client> # email, signing key, sshCommand
cp allowed-signers-work.example allowed-signers-work # client signing keys, one comment line each
ssh-keygen -t ed25519 -C "marshall@work-macbook" -f ~/.ssh/work-<client>
ssh-keygen -t ed25519 -C "marshall@work-macbook" -f ~/.ssh/work-<client>-signing
```

Replace `CLIENT` and the example values in each copy, then add `work-<client>.pub` as an authentication key and `work-<client>-signing.pub` as a signing key on the client's SCM.
