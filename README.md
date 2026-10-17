# longwire for Omarchy

A bar widget for [Omarchy](https://omarchy.org) that shows this machine's [longwire](https://longwire.ai) connection, and gets a new machine onto your account in one click.

longwire lets you reach the AI models running on your own machines (ollama, llama.cpp, LM Studio, vLLM…) from anywhere, through one private, OpenAI-compatible endpoint.

## What it shows

- **Not added yet:** the machine's pairing code, front and center. **Add in browser** opens longwire with the code filled in; sign in, confirm, done. Or copy the code and type it on any device.
- **Connected:** the machine's name on your account, how long it's been connected, and every model it shares, by engine.
- **Trouble:** reconnecting, the server unreachable, or the daemon stopped, with the reason and a one-click fix where there is one.

The packet dot in the middle of the mark is the status light: accent when connected, red when the machine needs you, dim when longwire isn't running.

## Install

On Omarchy, **Install › AI › longwire** (or `omarchy-install-ai-longwire`) installs the longwire daemon and this widget together, then opens the browser to add the machine.

To add just the widget:

```
omarchy plugin add https://github.com/nbitslabs/omarchy-longwire.git --enable
```

and install the daemon with `curl -fsSL https://longwire.ai/install.sh | sh`.

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
