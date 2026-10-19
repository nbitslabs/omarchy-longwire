#!/bin/bash
# Installs the longwire daemon release pinned in release.json and starts it
# as a systemd user service. The widget runs this for "Install longwire".
#
# Nothing here comes from the network except the binary itself, and that
# must match the SHA-256 pinned in release.json before it is installed — so
# what gets installed is exactly the release this plugin version was
# reviewed with. From then on the daemon keeps itself up to date, and only
# installs releases signed with longwire's release key (see the README).
#
# LONGWIRE_SERVER pairs the machine with a self-hosted longwire instead of
# longwire.ai; the binary is the same either way.
set -euo pipefail

plugin_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest="$plugin_dir/release.json"
download_base="$(jq -r .download_base "$manifest")"
version="$(jq -r .version "$manifest")"
server="${LONGWIRE_SERVER:-$(jq -r .server "$manifest")}"
server="${server%/}"

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "longwire doesn't support $(uname -m)" >&2; exit 1 ;;
esac
artifact="longwire_linux_$arch"
want="$(jq -r --arg a "$artifact" '.sha256[$a] // empty' "$manifest")"
[[ -n $want ]] || { echo "release.json pins no $artifact" >&2; exit 1; }

tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT

echo -e "\nDownloading longwire $version..."
curl -fsSL --connect-timeout 15 --max-time 300 --retry 2 -o "$tmp" "$download_base/$version/$artifact"
got="$(sha256sum "$tmp" | cut -d' ' -f1)"
if [[ $got != "$want" ]]; then
  echo "The download doesn't match the pinned release (got sha256 $got, expected $want). Nothing was installed." >&2
  exit 1
fi
echo "Verified sha256 $got"

bin="$HOME/.local/bin/longwire"
install -D -m 755 "$tmp" "$bin"

echo -e "\nStarting longwire..."
# Restarts a running daemon onto the new binary; a paired machine stays paired,
# and an auto_update setting already in its config is kept.
"$bin" service install --server "$server"

# A machine that isn't on an account yet shows a pairing code within a few
# seconds; open the link that adds it (via open-pairing.sh, which keeps the
# code off command lines).
for _ in {1..15}; do
  pair_url="$("$bin" status --json | jq -r '.pairing.url // empty')"
  state="$("$bin" status --json | jq -r '.state // empty')"
  [[ -n $pair_url || $state == connect* ]] && break
  sleep 1
done
echo
"$bin" status
if [[ -n ${pair_url:-} ]]; then
  echo -e "\nOpening longwire to add this machine to your account..."
  bash "$plugin_dir/open-pairing.sh" >/dev/null 2>&1 || true
fi
