import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Follows the longwire daemon through the status file it publishes at
// $XDG_RUNTIME_DIR/longwire/status.json. The daemon replaces that file
// atomically whenever its state changes, so this watches the directory (a
// FileView can't watch a file that doesn't exist yet, and a rename swaps the
// inode out from under a file watch) and re-reads on each change. Nothing
// here polls.
Item {
  id: root

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + (Quickshell.env("UID") || "1000"))
  readonly property string statusDir: runtimeDir + "/longwire"
  readonly property string statusPath: statusDir + "/status.json"

  property var status: null
  // true/false once probed; null while unknown. Only probed when there is no
  // status file, since a status file means the daemon ran.
  property var installed: null
  property bool dirReady: false
  property string actionStatus: ""

  readonly property string state: Model.viewState(status, installed)
  readonly property string headline: Model.headline(state, status)
  readonly property string server: Model.serverURL(status)
  readonly property string pairingCode: status && status.pairing ? String(status.pairing.code || "") : ""
  readonly property string pairingURL: status && status.pairing ? String(status.pairing.url || "") : ""
  readonly property var models: Model.modelRows(status)
  readonly property bool busy: startProcess.running || probeProcess.running

  function refresh() {
    statusFile.reload()
  }

  function applyText(text) {
    var parsed = Model.parseStatus(text)
    status = parsed.ok ? parsed.status : null
    if (!parsed.ok) probeInstalled()
  }

  function probeInstalled() {
    if (probeProcess.running) return
    probeProcess.running = true
  }

  function openURL(url) {
    if (url) Qt.openUrlExternally(url)
  }

  function openPairing() { openURL(pairingURL || (server + "/pair")) }
  function openChat() { openURL(server + "/chat") }
  function openDashboard() { openURL((status && status.dashboard_url) || (server + "/machines")) }

  function copyCode() {
    if (pairingCode === "") return
    Quickshell.execDetached(["wl-copy", pairingCode])
    flash("Copied " + pairingCode)
  }

  function start() {
    if (startProcess.running) return
    flash("Starting longwire…")
    startProcess.running = true
  }

  function install() {
    // Omarchy's install helper sets up the daemon and this widget together;
    // without it, fall back to longwire's own installer.
    Quickshell.execDetached(["bash", "-c",
      "if command -v omarchy-install-ai-longwire >/dev/null; then cmd=omarchy-install-ai-longwire; "
      + "else cmd='f=$(mktemp) && curl -fsSL --connect-timeout 15 --max-time 120 --retry 2 -o $f https://longwire.ai/install.sh && sh $f; s=$?; rm -f $f; (exit $s)'; fi; "
      + "exec omarchy-launch-floating-terminal-with-presentation \"$cmd\""])
  }

  function run(actionId) {
    if (actionId === "openPairing") openPairing()
    else if (actionId === "copyCode") copyCode()
    else if (actionId === "openChat") openChat()
    else if (actionId === "openDashboard") openDashboard()
    else if (actionId === "start") start()
    else if (actionId === "install") install()
  }

  function flash(text) {
    actionStatus = text
    flashTimer.restart()
  }

  Timer {
    id: flashTimer
    interval: 2400
    onTriggered: root.actionStatus = ""
  }

  FileView {
    id: statusFile
    path: root.statusPath
    printErrors: false
    onLoaded: root.applyText(text())
    onLoadFailed: root.applyText("")
  }

  // The daemon creates this directory on first run; creating it here first
  // lets the watch below catch that first run too (same 0700 mode).
  Process {
    running: true
    command: ["mkdir", "-p", "-m", "700", root.statusDir]
    onExited: root.dirReady = true
  }

  FileView {
    path: root.dirReady ? root.statusDir : ""
    watchChanges: true
    printErrors: false
    onFileChanged: statusFile.reload()
  }

  Process {
    id: probeProcess
    running: false
    command: ["bash", "-c", "command -v longwire >/dev/null || [[ -x $HOME/.local/bin/longwire ]]"]
    onExited: function(exitCode) { root.installed = exitCode === 0 }
  }

  Process {
    id: startProcess
    running: false
    command: ["systemctl", "--user", "start", "longwire.service"]
    onExited: function(exitCode) {
      if (exitCode !== 0) root.flash("Couldn't start longwire — run `longwire service install`")
    }
  }
}
