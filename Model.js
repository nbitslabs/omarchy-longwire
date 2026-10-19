// Pure logic for the longwire widget: parsing the daemon's status file and
// turning it into what the bar and panel show. No QML here, so it runs under
// Node for tests (see test/model-test.js).
//
// The status file is written by the longwire daemon at
// $XDG_RUNTIME_DIR/longwire/status.json (schema 1). Its states:
//   pairing       unpaired; `pairing` holds the code and the claim link
//   connecting    paired, opening the tunnel
//   connected     tunnel up
//   reconnecting  tunnel dropped; `last_error` says why
//   stopped       daemon exited cleanly
// The widget adds two of its own: "missing" (no status file, longwire is
// installed but the daemon isn't running) and "notInstalled".

var SUPPORTED_SCHEMA = 1

function parseStatus(text) {
  var raw = String(text || "").trim()
  if (raw === "") return { ok: false, status: null }
  try {
    var s = JSON.parse(raw)
    if (!s || typeof s !== "object" || typeof s.state !== "string") return { ok: false, status: null }
    // A newer daemon may add fields; only a schema bump means we can't read it.
    if (Number(s.schema || 0) > SUPPORTED_SCHEMA) return { ok: false, status: null, tooNew: true }
    if (!(s.backends instanceof Array)) s.backends = []
    return { ok: true, status: s }
  } catch (e) {
    return { ok: false, status: null }
  }
}

// The widget's view state from the parsed status (or null) and whether the
// longwire binary is installed (true/false, or null while unknown).
function viewState(status, installed) {
  if (status && status.state) {
    if (status.state === "pairing") return status.pairing && status.pairing.code ? "pairing" : "pairingOffline"
    if (status.state === "stopped") return "stopped"
    return status.state
  }
  if (installed === false) return "notInstalled"
  return "missing"
}

function hostOf(url) {
  var m = String(url || "").match(/^[a-z]+:\/\/([^\/?#]+)/i)
  return m ? m[1] : String(url || "")
}

function serverURL(status) {
  return String((status && status.server) || "https://longwire.ai").replace(/\/+$/, "")
}

function machineName(status) {
  return status && status.machine && status.machine.name ? String(status.machine.name) : ""
}

// One-line summary for the bar tooltip and the panel hero.
function headline(state, status) {
  var name = machineName(status)
  var host = hostOf(serverURL(status))
  switch (state) {
  case "connected": return name ? "Connected as " + name : "Connected"
  case "connecting": return "Connecting to " + host + "…"
  case "reconnecting": return "Reconnecting to " + host + "…"
  case "pairing": return "Waiting to be added to your account"
  case "pairingOffline": return "Can't reach " + host + " — retrying"
  case "stopped": return name ? "Not running" : "Not set up yet"
  case "notInstalled": return "Not installed"
  default: return "Starting…"
  }
}

// Whether the bar icon should draw attention (the machine needs the owner).
function needsAttention(state) {
  return state === "pairing" || state === "pairingOffline" || state === "reconnecting"
}

function isLive(state) {
  return state === "connected"
}

// "12 min", "2 h", "3 days" between two instants (ms); never negative.
function spanText(ms) {
  var s = Math.max(0, Math.floor(ms / 1000))
  if (s < 60) return s <= 1 ? "a moment" : s + " s"
  var m = Math.floor(s / 60)
  if (m < 60) return m + " min"
  var h = Math.floor(m / 60)
  if (h < 48) return h + " h"
  return Math.floor(h / 24) + " days"
}

function sinceText(iso, nowMs) {
  var t = Date.parse(String(iso || ""))
  if (!isFinite(t)) return ""
  return spanText(nowMs - t)
}

// When the current pairing code is replaced; the daemon swaps it on expiry.
function codeExpiryText(status, nowMs) {
  if (!status || !status.pairing) return ""
  var t = Date.parse(String(status.pairing.expires_at || ""))
  if (!isFinite(t)) return ""
  if (t - nowMs <= 60 * 1000) return "A new code appears in a moment"
  return "New code in " + spanText(t - nowMs)
}

// Flattens backends into model rows: [{ name, kind }], engines in order.
function modelRows(status) {
  var rows = []
  var backends = (status && status.backends) || []
  for (var i = 0; i < backends.length; i++) {
    var b = backends[i] || {}
    var models = b.models || []
    for (var j = 0; j < models.length; j++) rows.push({ name: String(models[j]), kind: String(b.kind || "") })
  }
  return rows
}

function engineSummary(status) {
  var backends = (status && status.backends) || []
  if (backends.length === 0) return "No engines found"
  var kinds = []
  for (var i = 0; i < backends.length; i++) kinds.push(String(backends[i].kind || "engine"))
  var n = modelRows(status).length
  return n + (n === 1 ? " model" : " models") + " · " + kinds.join(", ")
}

// The panel's actionable rows for a state, in display order. Each row is
// { id, icon, title, subtitle }; the panel maps ids to service calls.
function actions(state, status) {
  var host = hostOf(serverURL(status))
  switch (state) {
  case "pairing":
    return [
      { id: "openPairing", icon: "󰖟", title: "Add in browser", subtitle: "Sign in to " + host + " — the code is filled in" },
      { id: "copyCode", icon: "󰆏", title: "Copy code", subtitle: "Or type it at " + host + "/machines on any device" }
    ]
  case "connected":
  case "connecting":
  case "reconnecting":
    return [
      { id: "openChat", icon: "󰭻", title: "Chat", subtitle: "Talk to your models at " + host },
      { id: "openDashboard", icon: "󰒋", title: "Dashboard", subtitle: "Machines, keys and usage" }
    ]
  case "stopped":
  case "missing":
    return [{ id: "start", icon: "󰐊", title: "Start longwire", subtitle: "Runs in the background and starts with your computer" }]
  case "notInstalled":
    return [{ id: "install", icon: "󰇚", title: "Install longwire", subtitle: "Share this machine's local models privately" }]
  default:
    return []
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    viewState: viewState,
    hostOf: hostOf,
    serverURL: serverURL,
    machineName: machineName,
    headline: headline,
    needsAttention: needsAttention,
    isLive: isLive,
    spanText: spanText,
    sinceText: sinceText,
    codeExpiryText: codeExpiryText,
    modelRows: modelRows,
    engineSummary: engineSummary,
    actions: actions
  }
}
