# longwire for Omarchy

A bar widget for [Omarchy](https://omarchy.org) that shows this machine's [longwire](https://longwire.ai) connection, and gets a new machine onto your account in one click.

longwire lets you reach the AI models running on your own machines (ollama, llama.cpp, LM Studio, vLLM…) from anywhere, through one private, OpenAI-compatible endpoint.

## What it shows

- **Not added yet:** the machine's pairing code, front and center. **Add in browser** opens longwire with the code filled in; sign in, confirm, done. Or copy the code and type it on any device.
- **Connected:** the machine's name on your account, how long it's been connected, and every model it shares, by engine.
- **Trouble:** reconnecting, the server unreachable, or the daemon stopped, with the reason and a one-click fix where there is one.

The packet dot in the middle of the mark is the status light: accent when connected, red when the machine needs you, dim when longwire isn't running.

## Install

```
omarchy plugin add https://github.com/nbitslabs/omarchy-longwire.git --enable
```

If the longwire daemon isn't on this machine yet, the widget offers **Install longwire**. That runs [`install-longwire.sh`](install-longwire.sh) from this plugin in a terminal, which:

1. downloads the exact longwire release pinned in [`release.json`](release.json) from `https://longwire.ai/downloads/<version>/`,
2. checks it against the SHA-256 pinned there, and installs nothing if it doesn't match,
3. installs it to `~/.local/bin/longwire` and starts it as a systemd user service,
4. opens the browser to add the machine to your account.

So the first binary on your machine is the release this plugin version was reviewed with, not whatever the server is serving that day.

After that the daemon keeps itself up to date, independently of plugin updates. It only installs a new release whose `SHA256SUMS` is signed with longwire's release key, which is compiled into the daemon and never kept on the server, so a compromised server can't push a build longwire didn't release. To manage updates yourself instead, set `"auto_update": false` in `~/.config/longwire/config.json` and run `systemctl --user restart longwire`; `longwire status` shows whether updates are on.

Every longwire release is also published with a signed `SHA256SUMS` alongside the binaries, so you can check a pin yourself:

```
curl -fsSL https://longwire.ai/downloads/$(jq -r .version release.json)/SHA256SUMS
```

To pair with a self-hosted longwire instead, set `LONGWIRE_SERVER=https://your-server` when running `install-longwire.sh`.

## Remove

```
omarchy plugin remove nbitslabs.longwire
```

removes the widget. The longwire daemon is separate; to remove it too:

```
longwire service uninstall
rm ~/.local/bin/longwire
rm -r ~/.config/longwire
```

Removing `~/.config/longwire` forgets this machine's credential; delete the machine from your [dashboard](https://longwire.ai/machines) as well.

## Using it

- **Left click** opens the panel; **right click** does whatever the machine needs next (add it in the browser, or open the dashboard); **middle click** refreshes.
- In the panel: `j`/`k` or arrows to move, `enter` to act, `o` for the first action, `c` to copy the pairing code, `d` for the dashboard, `r` to refresh, `esc` to close.
- IPC: `omarchy-shell nbitslabs.longwire status | code | pair | refresh | open | close | toggle`.

## How it works

The longwire daemon publishes its state to `$XDG_RUNTIME_DIR/longwire/status.json` whenever it changes ([format](https://github.com/nbitslabs/longwire#pairing-and-desktop-integrations)). The widget watches that directory and re-reads the file on change, so it never polls and starts no processes while idle. Opening links uses your default browser; copying uses `wl-copy`.

## Development

`Model.js` holds all the logic that isn't drawing and runs under Node:

```
node test/model-test.js
```

Drop a checkout into `~/.config/omarchy/plugins/nbitslabs.longwire/` and Omarchy reloads it on every save. Validate before publishing with `omarchy plugin validate .`.

The widget runs on Omarchy 4.0.4 and later.

## License

MIT
