// node test/model-test.js — unit tests for Model.js
const assert = require("assert")
const path = require("path")
const M = require(path.join(__dirname, "..", "Model.js"))

let n = 0
function t(name, fn) {
  fn()
  n++
  console.log("ok - " + name)
}

const NOW = Date.parse("2026-10-17T07:00:00Z")
const pairing = {
  schema: 1, state: "pairing", server: "https://longwire.ai",
  pairing: { code: "42-otter-piano", url: "https://longwire.ai/pair?code=42-otter-piano", expires_at: "2026-10-17T07:12:30Z" },
  backends: []
}
const connected = {
  schema: 1, state: "connected", since: "2026-10-17T05:00:00Z", server: "https://longwire.ai/",
  machine: { id: "m1", name: "omarchy" },
  backends: [
    { kind: "ollama", url: "http://127.0.0.1:11434", models: ["gemma4:e4b", "qwen3:8b"] },
    { kind: "llamacpp", url: "http://127.0.0.1:8080", models: ["phi-4"] }
  ]
}

t("parses a status file", () => {
  const r = M.parseStatus(JSON.stringify(pairing))
  assert.ok(r.ok)
  assert.strictEqual(r.status.pairing.code, "42-otter-piano")
})

t("rejects empty, garbage, and stateless input", () => {
  assert.ok(!M.parseStatus("").ok)
  assert.ok(!M.parseStatus("{nope").ok)
  assert.ok(!M.parseStatus("{}").ok)
})

t("tolerates new fields but not a newer schema", () => {
  assert.ok(M.parseStatus(JSON.stringify({ ...connected, future_field: 1 })).ok)
  const r = M.parseStatus(JSON.stringify({ ...connected, schema: 2 }))
  assert.ok(!r.ok && r.tooNew)
})

t("defaults missing backends to an empty list", () => {
  const r = M.parseStatus('{"state":"connecting"}')
  assert.deepStrictEqual(r.status.backends, [])
})

t("maps daemon states to view states", () => {
  assert.strictEqual(M.viewState(pairing, true), "pairing")
  assert.strictEqual(M.viewState({ state: "pairing", pairing: null }, true), "pairingOffline")
  assert.strictEqual(M.viewState(connected, true), "connected")
  assert.strictEqual(M.viewState({ state: "stopped" }, true), "stopped")
  assert.strictEqual(M.viewState(null, false), "notInstalled")
  assert.strictEqual(M.viewState(null, true), "missing")
  assert.strictEqual(M.viewState(null, null), "missing")
})

t("headlines name the machine and server", () => {
  assert.strictEqual(M.headline("connected", connected), "Connected as omarchy")
  assert.strictEqual(M.headline("reconnecting", connected), "Reconnecting to longwire.ai…")
  assert.strictEqual(M.headline("pairingOffline", pairing), "Can't reach longwire.ai — retrying")
  assert.strictEqual(M.headline("stopped", { state: "stopped" }), "Not set up yet")
  assert.strictEqual(M.headline("stopped", connected), "Not running")
})

t("only pairing and trouble draw attention", () => {
  assert.ok(M.needsAttention("pairing"))
  assert.ok(M.needsAttention("reconnecting"))
  assert.ok(!M.needsAttention("connected"))
  assert.ok(!M.needsAttention("stopped"))
})

t("server URLs lose trailing slashes; hosts drop scheme and path", () => {
  assert.strictEqual(M.serverURL(connected), "https://longwire.ai")
  assert.strictEqual(M.hostOf("http://10.0.2.2:8990/machines"), "10.0.2.2:8990")
  assert.strictEqual(M.serverURL(null), "https://longwire.ai")
})

t("spans read naturally", () => {
  assert.strictEqual(M.spanText(500), "a moment")
  assert.strictEqual(M.spanText(42 * 1000), "42 s")
  assert.strictEqual(M.spanText(12 * 60 * 1000), "12 min")
  assert.strictEqual(M.spanText(2 * 3600 * 1000), "2 h")
  assert.strictEqual(M.spanText(3 * 86400 * 1000), "3 days")
  assert.strictEqual(M.spanText(-5000), "a moment")
  assert.strictEqual(M.sinceText(connected.since, NOW), "2 h")
  assert.strictEqual(M.sinceText("not a date", NOW), "")
})

t("code expiry counts down, then promises a fresh code", () => {
  assert.strictEqual(M.codeExpiryText(pairing, NOW), "New code in 12 min")
  assert.strictEqual(M.codeExpiryText(pairing, Date.parse("2026-10-17T07:12:00Z")), "A new code appears in a moment")
  assert.strictEqual(M.codeExpiryText(connected, NOW), "")
})

t("models flatten across engines", () => {
  assert.deepStrictEqual(M.modelRows(connected).map((r) => r.name + "@" + r.kind),
    ["gemma4:e4b@ollama", "qwen3:8b@ollama", "phi-4@llamacpp"])
  assert.strictEqual(M.engineSummary(connected), "3 models · ollama, llamacpp")
  assert.strictEqual(M.engineSummary({ backends: [] }), "No engines found")
  assert.strictEqual(M.engineSummary({ backends: [{ kind: "ollama", models: ["a"] }] }), "1 model · ollama")
})

t("actions fit the state", () => {
  assert.deepStrictEqual(M.actions("pairing", pairing).map((a) => a.id), ["openPairing", "copyCode"])
  assert.deepStrictEqual(M.actions("connected", connected).map((a) => a.id), ["openChat", "openDashboard"])
  assert.deepStrictEqual(M.actions("stopped", {}).map((a) => a.id), ["start"])
  assert.deepStrictEqual(M.actions("notInstalled", null).map((a) => a.id), ["install"])
  assert.deepStrictEqual(M.actions("pairingOffline", pairing), [])
  assert.ok(M.actions("pairing", pairing)[0].subtitle.includes("longwire.ai"))
})

t("offers an update only to daemons the plugin manages", () => {
  const pinned = { ...connected, version: "v1", auto_update: false }
  assert.ok(M.updateAvailable(pinned, "v2"))
  assert.ok(!M.updateAvailable(pinned, "v1"))
  assert.ok(!M.updateAvailable({ ...pinned, auto_update: true }, "v2"), "self-updating daemons update themselves")
  assert.ok(!M.updateAvailable({ ...pinned, version: "dev" }, "v2"))
  assert.ok(!M.updateAvailable(pinned, ""))
  assert.deepStrictEqual(M.actions("connected", pinned, "v2").map((a) => a.id), ["openChat", "openDashboard", "update"])
  assert.strictEqual(M.actions("connected", pinned, "v2")[2].subtitle, "v1 → v2")
  assert.deepStrictEqual(M.actions("notInstalled", null, "v2").map((a) => a.id), ["install"])
})

t("release.json pins a release for every Linux architecture", () => {
  const rel = require(path.join(__dirname, "..", "release.json"))
  assert.match(rel.version, /^[A-Za-z0-9][A-Za-z0-9._+-]*$/)
  assert.strictEqual(rel.server, "https://longwire.ai")
  assert.strictEqual(rel.download_base, "https://longwire.ai/downloads")
  for (const a of ["longwire_linux_amd64", "longwire_linux_arm64"]) assert.match(rel.sha256[a], /^[0-9a-f]{64}$/, a)
})

console.log(`1..${n}`)
