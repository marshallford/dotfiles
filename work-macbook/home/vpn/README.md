# VPN

For clients on GlobalProtect with SAML sign-in. `gpclient` from [GP Connect](https://github.com/yuezk/GlobalProtect-openconnect) handles the login and tunnel. [vpn-slice](https://github.com/dlenski/vpn-slice) replaces the gateway's routes and DNS with the settings below.

`gpclient` comes from the [Brewfile](../../Brewfile). vpn-slice's last release predates its macOS fixes, so install a pinned commit, root-owned since it runs as root. Rerun with a newer commit to upgrade:

```shell
c=da919cd0e92213613d185c4634c33766eca77a9d
sudo -H env UV_TOOL_DIR=/usr/local/libexec/uv/tools UV_PYTHON_INSTALL_DIR=/usr/local/libexec/uv/python UV_TOOL_BIN_DIR=/usr/local/bin \
    "$(command -v uv)" tool install --managed-python "vpn-slice[dnspython] @ git+https://github.com/dlenski/vpn-slice@$c"
sudo /usr/local/bin/vpn-slice --self-test
```

Settings are client-identifying, so they go in `~/.zshenv.private`, space separated:

```shell
export VPN_PORTAL='vpn.example.com'
export VPN_GATEWAY='gw.example.com' # name or address
export VPN_ROUTES='10.42.0.0/16 172.22.40.0/24' # through the tunnel; all other traffic stays local
export VPN_DNS_DOMAINS='corp.example.com example.internal' # resolved by the VPN nameservers via /etc/resolver
export VPN_HOSTS='git.example.internal' # looked up via the VPN at connect, routed, added to /etc/hosts
```

- `vpn-up` opens the browser for the SAML login, then runs in the background, logging to `/var/log/gpclient.log`
- `vpn-down` disconnects, removing the routes, resolver files and hosts entries
- `vpn-status` shows where each route and domain goes
- `vpn-reset` undoes what a crash or `kill -9` leaves behind

The [SwiftBar](https://swiftbar.app) menu shows the same status and runs these commands: in the background once Touch ID approves sudo, otherwise in a Ghostty window that asks for the password. SwiftBar comes from the Brewfile but has no default plugin folder, so set it before the first launch:

```shell
defaults write com.ameba.SwiftBar PluginDirectory -string ~/.config/swiftbar
```

Option-click the VPN icon for SwiftBar's own menu, where Preferences has Launch at Login.
