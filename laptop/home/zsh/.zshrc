# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt EXTENDED_HISTORY       # include timestamp
setopt HIST_EXPIRE_DUPS_FIRST # trim dupes first if history is full
setopt HIST_FIND_NO_DUPS      # do not display previously found command
setopt HIST_IGNORE_DUPS       # do not save duplicate of prior command
setopt HIST_IGNORE_SPACE      # do not save if line starts with space
setopt HIST_NO_STORE          # do not save history commands
setopt HIST_REDUCE_BLANKS     # strip superfluous blanks
setopt INC_APPEND_HISTORY     # don’t wait for shell to exit to save history lines

# Appearance
if [[ -z "${LS_COLORS-}" ]]; then
  if (( $+commands[dircolors] )); then
    if [[ -r ~/.dircolors ]]; then
      eval "$(dircolors -b ~/.dircolors)"
    else
      eval "$(dircolors -b)"
    fi
  else
    export LS_COLORS="di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
  fi
fi

# Completion
zmodload -i zsh/complist # enable interactive completion menus and selection
WORDCHARS=''             # treat only alphanumerics as word characters

unsetopt MENU_COMPLETE  # don't auto-insert the first completion match
unsetopt FLOWCONTROL    # disable Ctrl-S / Ctrl-Q terminal freezing
setopt AUTO_MENU        # show completion menu on repeated tab presses
setopt COMPLETE_IN_WORD # allow completion in the middle of a word
setopt ALWAYS_TO_END    # move cursor to end after completion

zstyle ':completion:*' menu select                                                                          # enable interactive menu selection for completion
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}' 'r:|=*' 'l:|=* r:|=*' # case insensitive, underscores and hyphens interchangeable
zstyle ':completion:*' special-dirs true                                                                    # include . and .. in completion results
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}                                                       # use LS_COLORS for completion lists
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'            # colorize PIDs and process names in kill completion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories                    # prefer local dirs, then dir stack, then $PATH dirs for cd completion
zstyle '*' single-ignored show                                                                              # show the lone ignored match instead of hiding it

# Keybindings
bindkey -e                                       # use emacs-style editing
bindkey '^r' history-incremental-search-backward # reverse history search with Ctrl-R
bindkey ' '  magic-space                         # expand history on space

(( ${+terminfo[kcbt]} )) && bindkey "${terminfo[kcbt]}" reverse-menu-complete # shift-tab cycles completion backward
(( ${+terminfo[kcuu1]} )) && bindkey "${terminfo[kcuu1]}" up-line-or-search   # move up a line in multiline input, otherwise do a loose history search
(( ${+terminfo[kcud1]} )) && bindkey "${terminfo[kcud1]}" down-line-or-search # move down a line in multiline input, otherwise do a loose history search
(( ${+terminfo[khome]} )) && bindkey "${terminfo[khome]}" beginning-of-line   # home
(( ${+terminfo[kend]}  )) && bindkey "${terminfo[kend]}"  end-of-line         # end
(( ${+terminfo[kdch1]} )) && bindkey "${terminfo[kdch1]}" delete-char         # delete

autoload -U edit-command-line    # autoload the edit-command-line ZLE function
zle -N edit-command-line         # register edit-command-line as a ZLE widget
bindkey '^X^E' edit-command-line # bind Ctrl-X then Ctrl-E to edit the command in $VISUAL/$EDITOR

# Misc
zle_highlight=('paste:none') # don't highlight pasted text

setopt multios             # allow: cmd >file1 >file2
setopt long_list_jobs      # more informative job notifications
setopt interactivecomments # allow comments in interactive shell

# Antidote Setup
zsh_plugins=${ZDOTDIR:-~}/.zsh_plugins

fpath=(/usr/share/zsh-antidote/functions $fpath)
autoload -Uz antidote

if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  antidote bundle <${zsh_plugins}.txt >|${zsh_plugins}.zsh
fi

source ${zsh_plugins}.zsh

# Prompt
autoload -U promptinit; promptinit
prompt pure

# Aliases
alias _='sudo '
alias diff='diff --color=auto'
alias ls='ls --color=auto'
alias lso="ls -alG | awk '{k=0;for(i=0;i<=8;i++)k+=((substr(\$1,i+2,1)~/[rwx]/)*2^(8-i));if(k)printf(\" %0o \",k);print}'"
alias grep='grep --color=auto'
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'
alias g='git'
alias export-vscode-extensions="code --list-extensions > $DOTFILES/$DOTFILES_MACHINE/vscode-extensions.txt"
alias import-vscode-extensions="cat $DOTFILES/$DOTFILES_MACHINE/vscode-extensions.txt | xargs -L 1 code --install-extension"
alias updater='yay -Syu'
alias cleaner='yay -Rns $(pacman -Qtdq)'
alias repo-updater='sudo reflector --save /etc/pacman.d/mirrorlist --protocol https --age 2 --fastest 5 --number 10 --sort rate --ipv4'

# SSH Agent (enabled separately: `systemctl --user enable --now ssh-agent.socket`)
if [[ -z ${SSH_CONNECTION-} ]] && [[ -n ${XDG_RUNTIME_DIR-} ]]; then
  ssh_agent_sock="$XDG_RUNTIME_DIR/ssh-agent.socket"
  if [[ (-z ${SSH_AUTH_SOCK-} || ! -S $SSH_AUTH_SOCK) && -S $ssh_agent_sock ]]; then
    export SSH_AUTH_SOCK="$ssh_agent_sock"
  fi
  unset ssh_agent_sock
fi

# CLI Setup
[[ -s /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh
