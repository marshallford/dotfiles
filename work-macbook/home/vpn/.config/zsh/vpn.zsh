# GlobalProtect VPN, see work-macbook/home/vpn/README.md; VPN_* are set in ~/.zshenv.private

# --hip sends gpclient's report: this Mac's identity, templated posture
vpn-up() {
  [[ -n $VPN_PORTAL && -n $VPN_GATEWAY ]] || { print -u2 'set VPN_PORTAL and VPN_GATEWAY in ~/.zshenv.private'; return 1 }
  [[ $(vpn-status | head -1) == stale ]] && { vpn-reset || return }
  sudo gpclient connect "$VPN_PORTAL" --gateway="$VPN_GATEWAY" --browser --hip --background \
    --script "/usr/local/bin/vpn-slice --name vpn --domains-vpn-dns=${VPN_DNS_DOMAINS// /,} $VPN_ROUTES $VPN_HOSTS"
}

# Returns once gpclient has exited and vpn-slice has cleaned up
vpn-down() {
  sudo gpclient disconnect || return
  while pgrep -q gpclient; do sleep 0.5; done
}

# First line is connected, connecting, stale (a crashed session's leftovers, see vpn-reset) or disconnected.
# dig and nslookup skip /etc/resolver; check a name with: dscacheutil -q host -a name <host>
vpn-status() {
  local r d state=disconnected first=${VPN_ROUTES%% *}
  if pgrep -q gpclient; then
    state=connecting
    [[ -z $first || $(route -n get ${first%/*} 2>/dev/null) == *'interface: utun'* ]] && state=connected
  else
    grep -q '# vpn-slice-vpn AUTOCREATED$' /etc/hosts && state=stale
    for d in ${=VPN_DNS_DOMAINS}; do [[ -e /etc/resolver/$d ]] && state=stale; done
  fi
  print $state
  for r in ${=VPN_ROUTES}; do
    print -r -- "$r via ${$(route -n get ${r%/*} 2>/dev/null | awk '/interface:/ {print $2}'):-none}"
  done
  for d in ${=VPN_DNS_DOMAINS}; do
    print -r -- "$d resolver ${$(awk '/^nameserver/ {printf "%s ", $2}' /etc/resolver/$d 2>/dev/null):-none}"
  done
}

# Undo what vpn-slice leaves behind when gpclient crashes or is killed
vpn-reset() {
  local d gw
  pgrep -q gpclient && { print -u2 'gpclient is running, use vpn-down'; return 1 }
  for d in ${=VPN_DNS_DOMAINS}; do sudo rm -f /etc/resolver/$d; done
  grep -q '# vpn-slice-vpn AUTOCREATED$' /etc/hosts && sudo sed -i '' '/# vpn-slice-vpn AUTOCREATED$/d' /etc/hosts
  grep -q '# vpn-slice-utun[0-9]* AUTOCREATED' /etc/pf.conf &&
    sudo sed -i '' '/# vpn-slice-utun[0-9]* AUTOCREATED/d' /etc/pf.conf && sudo pfctl -q -f /etc/pf.conf
  # Host route to the gateway; dig skips /etc/resolver, so this works before cleanup too
  gw=${$(dig +short "$VPN_GATEWAY" 2>/dev/null | tail -1):-$VPN_GATEWAY}
  netstat -rn -f inet | awk -v g=$gw '$1 == g {f = 1} END {exit !f}' && sudo route -n delete $gw
  return 0
}
