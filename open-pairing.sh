#!/bin/bash
# Opens the link that adds this machine to a longwire account. The link
# carries the machine's pairing code, and a browser started with it would put
# the code on its command line, where other local users can read it. So the
# browser gets a private redirect page instead. The page lives in the
# daemon's runtime directory, which is 0700 like the status file the link
# comes from, and only its path shows up on a command line.
set -euo pipefail

dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/longwire"
url="$(jq -r '.pairing.url // empty' "$dir/status.json" 2>/dev/null || true)"
if [[ $url != http://* && $url != https://* ]]; then
  echo "This machine has no pairing link right now." >&2
  exit 1
fi
href="$(jq -rn --arg u "$url" '$u | @html')"

page="$(mktemp --suffix=.html -p "$dir" pair.XXXXXX)"
cat >"$page" <<HTML
<!doctype html>
<meta charset="utf-8">
<meta name="referrer" content="no-referrer">
<meta http-equiv="refresh" content="0;url=$href">
<title>longwire</title>
<a href="$href">Add this machine to longwire</a>
HTML
# The browser reads the page once; the code expires soon after anyway.
(sleep 60; rm -f -- "$page") </dev/null >/dev/null 2>&1 &

if command -v omarchy-launch-browser >/dev/null; then
  exec omarchy-launch-browser "file://$page"
fi
exec xdg-open "file://$page"
