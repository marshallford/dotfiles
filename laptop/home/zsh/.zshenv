# Environment Variables
export EDITOR='nano'
export VISUAL=${VISUAL:-$EDITOR}
export PAGER=${PAGER:-less}
export LESS=${LESS:--R}
export LESSHISTFILE='-'
export DOTFILES="$HOME/Documents/Projects/dotfiles"
export DOTFILES_MACHINE='laptop'
export GOPATH="$HOME/.go"
export TFENV_CONFIG_DIR="$HOME/.tfenv"

# PATH
typeset -U path PATH
[[ -d $HOME/.local/bin ]] && path=($HOME/.local/bin $path)
[[ -d $GOPATH/bin ]] && path=($GOPATH/bin $path)
