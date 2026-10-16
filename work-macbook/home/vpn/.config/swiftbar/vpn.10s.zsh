#!/bin/zsh
# shellcheck disable=SC1071
# <xbar.title>VPN</xbar.title>
# <xbar.desc>GlobalProtect VPN status and controls from ~/.config/zsh/vpn.zsh</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

source ~/.config/zsh/vpn.zsh
self=${SWIFTBAR_PLUGIN_PATH:-$0}
log=${SWIFTBAR_PLUGIN_CACHE_PATH:-${TMPDIR:-/tmp}}/vpn.log

# Types into a new Ghostty window's shell; passing a command instead would make Ghostty wait after it exits
ghostty() {
  osascript -e "tell application \"Ghostty\" to new window with configuration {initial input:(\" $1\" & linefeed)}" >/dev/null
}

run() {
  case $1 in
    restart) vpn-down && vpn-up ;;
    *) vpn-$1 ;;
  esac
}

# Menu actions run in the background once Touch ID authorises sudo, showing the output in Ghostty only on
# failure. Without Touch ID (lid closed, cancelled) they rerun in a Ghostty window, where sudo asks for the password.
case $1 in
  up|down|reset|restart)
    if [[ -t 0 ]]; then
      run $1 || read -sk '?Failed, press any key to close'
    elif sudo -v 2>/dev/null; then
      mkdir -p ${log:h}
      run $1 >$log 2>&1 || ghostty "cat '$log'; read -sk '?Failed, press any key to close'; exit"
    else
      ghostty "exec '$self' $1"
    fi
    open -g 'swiftbar://refreshplugin?name=vpn'
    exit
    ;;
esac

lines=("${(@f)$(vpn-status)}")
state=$lines[1]

case $state in
  connected) print '| sfimage=lock.shield.fill' ;;
  connecting) print '| sfimage=lock.shield' ;;
  stale) print '| sfimage=exclamationmark.shield sfcolor=orange' ;;
  *) print '| sfimage=shield.slash' ;;
esac
print -- ---
print -r -- ${(C)state}
print -rl -- $lines[2,-1]
print -- ---
case $state in
  connected|connecting)
    print "Disconnect | bash=\"$self\" param1=down terminal=false"
    print "Restart | bash=\"$self\" param1=restart terminal=false"
    ;;
  stale)
    print "Reset | bash=\"$self\" param1=reset terminal=false"
    print "Connect | bash=\"$self\" param1=up terminal=false"
    ;;
  *) print "Connect | bash=\"$self\" param1=up terminal=false" ;;
esac
print 'Refresh | refresh=true'
