---
name: omarchy-plugin
description: Use when creating, cloning, debugging, validating, installing, or publishing third-party Omarchy Quattro shell plugins built with QML and Quickshell, including bar widgets, panels, overlays, menus, services, and full bar replacements.
---

# Omarchy Plugin

## Overview

Omarchy Quattro plugins are QML components loaded by the existing long-running `omarchy-shell` process. Build against the official `manifest.json` contract and the installed Omarchy shell APIs; do not treat a plugin as an independent Quickshell application.

**Reference-only sources:** [references/omarchy-plugin-reference.md](references/omarchy-plugin-reference.md) and [references/quickshell-reference.md](references/quickshell-reference.md). The installed Omarchy branch and its `shell/` source win when versions disagree.

## When to Use

- Create or clone a custom `bar-widget`, `panel`, `overlay`, `menu`, `service`, or `bar` plugin.
- Connect QML entry points to Omarchy bar/panel lifecycle, IPC, settings, or shared shell services.
- Validate, reload, enable, disable, install, update, remove, or publish a plugin.
- Diagnose manifest, discovery, `qmllint`, panel lifecycle, or Quickshell import failures.

Do not use this for a standalone Quickshell configuration intentionally launched with `qs`/ `quickshell`; that is a different deployment model and must not be presented as an Omarchy plugin.

## Required Workflow

### 1. Choose the contract

Start from the closest official plugin. The kind determines the manifest key and entry file:

| `kinds` value | `entryPoints` key | Typical role |
|---|---|---|
| `bar-widget` | `barWidget` | Item placed in the active bar |
| `panel` | `panel` | Persistent or summoned floating surface |
| `overlay` | `overlay` | Fullscreen overlay |
| `menu` | `menu` | Summoned menu surface |
| `service` | `service` | Headless singleton |
| `bar` | `bar` | Full bar replacement; only one is active |

For an existing built-in, clone it into user config:

```bash
omarchy plugin clone omarchy.clock --edit
```

Use the exact ID printed by the command. Work under `~/.config/omarchy/plugins/<plugin-id>/`; never edit packaged Omarchy source. Saving files reloads plugin code; force discovery with `omarchy-shell shell rescanPlugins`.

During clone development, preserve the generated `omarchy.clonedFrom` and any built-in routing identifiers that the clone command leaves in `moduleName`/IPC targets; Omarchy routes existing built-in callers to the active clone. Do not mass-replace those values while the clone is still replacing the built-in. Only before publishing, remove clone-only metadata and update every `moduleName`, `ipcTarget`, and related caller to the permanent third-party ID.

### 2. Define `manifest.json`

The manifest is at the repository/plugin root. Use a namespaced third-party ID, never an `omarchy.*` ID:

```json
{
  "schemaVersion": 1,
  "id": "io.github.yourname.clock",
  "name": "Custom Clock",
  "version": "1.0.0",
  "author": "Your name",
  "license": "MIT",
  "description": "A clock for the Omarchy bar.",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "Custom Clock",
    "category": "Time",
    "allowMultiple": false,
    "defaultSection": "center"
  }
}
```

`entryPoints` values must be safe relative paths and match case-sensitive filenames. Plugin folders must not contain symlinks. A clone may retain `omarchy.clonedFrom` during development; remove it and choose the permanent namespaced ID before publishing.

### 3. Implement inside the existing shell

For a simple bar widget, use Omarchy's `BarWidget` and `WidgetButton` types rather than creating a new `PanelWindow` or starting another Quickshell process:

```qml
import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.yourname.clock"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Qt.formatTime(clock.date, "HH:mm")
    tooltipText: "Custom Clock"
  }
}
```

For a bar widget with a popup, keep the popup as a nested `Panel.qml` loaded with `Qt.resolvedUrl("Panel.qml")`. Use the same `moduleName` in both files; forward `opened`, `open()`, `close()`, `toggle()`, `closeForPopoutSwitch()`, and the injected `bar`, `anchorItem`, and `hostWidget`. Use Omarchy's `KeyboardPanel` and `PanelKeyCatcher` so bar anchoring, Escape, focus, and panel handoff remain intact.

Use Quickshell modules deliberately: `QtQuick` for QML items, `Quickshell` for shell primitives such as `SystemClock`, `Quickshell.Wayland` for layer-shell windows, and the modules exposed by the installed Omarchy shell for `qs.*` types. Do not copy a standalone `ShellRoot`/`PanelWindow` architecture into a plugin unless the selected Omarchy kind explicitly requires it.

### 4. Validate before enabling

```bash
PLUGIN_ID="io.github.yourname.clock"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" +  "$PLUGIN_DIR/BarWidget.qml"
```

Both commands must exit successfully. If `OMARCHY_PATH` is unset, locate the installed Omarchy shell source/import path first; do not guess an unrelated Quickshell import directory.

| Failure | Recovery |
|---|---|
| Manifest parse/required-field error | Fix JSON and required `schemaVersion`, identity, `kinds`, and `entryPoints`. |
| Entry point file not found | Match the manifest path and on-disk filename, including capitalization. |
| Valid but not listed | Run `omarchy-shell shell rescanPlugins`, then `omarchy plugin list --json`. |
| Listed but not visible | Enable it, confirm the declared kind, and inspect `qs log -p "$OMARCHY_PATH/shell" --tail 100`. |
| Popup opens only once | Forward the panel lifecycle and use the host bar widget as `owner`. |
| QML type/import error | Check the installed Omarchy branch and Quickshell version; do not invent a replacement type. |
| `X is not a type` for a type the file clearly imports | Clear the QML compile cache first — a stale *failed* compile replays old errors: `rm -rf ~/.cache/quickshell/qmlcache` then `omarchy restart shell`. See Platform pitfalls. |
| `Rectangle is not a type` in a file that obviously imports QtQuick | The file has no import block at all; QML reports the first unresolved type, never "missing imports". |
| Loads cleanly but renders nothing, log empty | A helper used `Array.isArray()` on a list-like QML value. See Platform pitfalls. |
| `Binding loop detected for property X` | The binding reads a plugin-API object (`bar.layoutConfig`, `bar.clickTargets`) that the bar replaces on every sync. Cache a scalar instead. |
| `Invalid property assignment: "implicitHeight" is a read-only property` | `Text` computes its implicit size and has no setter; use `height:`. |
| A fix does not take effect (same line/column as before) | The QML disk cache kept the failed compile: `rm -rf ~/.cache/quickshell/qmlcache` then `omarchy restart shell`. |

🔴 CHECKPOINT — do not enable a plugin you have not read. Plugins run
unsandboxed inside the shell with the user's permissions; `validate` only
proves the manifest is well-formed.

### 5. Platform pitfalls (third-party plugins)

Each of these is a real failure with a reproduction, not a style preference.

**A stale QML compile cache fakes type errors. Clear it before believing any.**

`ScrollBar is not a type`, `Rectangle is not a type`, `Type Foo unavailable` —
when a file imports the right module and a sibling with the same pattern loads
fine, suspect the cache, not the code. The disk cache keeps a *failed* compile
and replays it after the file is fixed, so the same error (often at the old line
and column) survives copying a corrected file into the plugin folder and
rescanning.

```bash
rm -rf ~/.cache/quickshell/qmlcache
omarchy restart shell
```

This cost several rounds of false debugging: a file that reported
`ScrollBar is not a type` compiled cleanly the moment the cache was cleared —
its original version had no import block at all, and that first failure had
poisoned every later attempt.

**`QtQuick.Controls` does work in a user plugin.** Marketplace listings ship
`ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }` and resolve fine
(see `dizziee.cline-model-usage`, `markbusai.opencode-usage`). Put
`import QtQuick.Controls` at the top of every file that instantiates a Controls
type — including files pulled in as types from the entry point, not just the
entry point itself. Only if a Controls type still will not resolve *after*
clearing the cache should you fall back to a `qs.Ui` component or a hand-drawn
affordance.

**List-like QML values are not JS Arrays.**

```js
Array.isArray(SystemTray.items.values)   // false, even with 5 items in it
```

So `Array.isArray(items) ? items : []` returns `[]`, `visible:` stays false and
the widget renders as an empty slot **with no error logged**. Treat anything
with a numeric `length` as a list and copy it before slicing:

```js
function asList(value) {
  var out = []
  if (!value || typeof value.length !== "number") return out
  for (var i = 0; i < value.length; i++) out.push(value[i])
  return out
}
```

**Plugin-API objects are replaced on every sync, which loops bindings.**

The bar hands the plugin a **fresh object** for `bar.layoutConfig` on every
plugin sync, and registering a click target triggers one. A binding that reads
the layout re-enters itself: partition → new arrays → Repeater rebuilds → click
targets register → bar re-syncs → `layoutConfig` replaced → partition again,
reported as `Binding loop detected for property "trayState"`. Never read
`bar.layoutConfig` / `bar.clickTargets` from a binding; cache a scalar that only
notifies when its value really changes:

```js
property bool ownsDropbox: false

function syncLayoutOwnership() {
  root.ownsDropbox = TrayModel.layoutHasWidget(
    root.bar ? root.bar.layoutConfig : null, "omarchy.dropbox")
}
```

**`Text.implicitHeight` is read-only.** `Item` has writable implicit sizes;
`Text` computes them. Use `height:`.

**A fixed file can keep failing.** The QML disk cache keeps a failed compile, so
the same error survives copying a corrected file into the plugin folder. Clear
it before debugging anything that "should be fixed already":

```bash
rm -rf ~/.cache/quickshell/qmlcache
omarchy restart shell
```

**Same-owner panels and menus do not close each other.** `requestPopout(owner)`
returns early when `activePopout === owner`, so a panel and a popup menu sharing
the bar widget as `owner` stay open together. Close the other surface
explicitly before opening one.

**Debugging a plugin that shows nothing.**

1. `qs log -p "$OMARCHY_PATH/shell" --tail 100` — QML failures are logged, but a
   component that loads cleanly and renders nothing logs nothing at all.
2. Add a one-shot probe to the widget, read the log, then remove it:
   ```qml
   Timer {
     interval: 2500
     running: true
     onTriggered: console.log("PROBE: shown=" + root.shownItems.length
       + " visible=" + root.visible + " iw=" + root.implicitWidth
       + " len=" + SystemTray.items.values.length)
   }
   ```
3. `omarchy-shell shell summon <plugin-id>` — a bar widget exposing
   `open()`/`close()`/`opened` is summonable, returns `ok` when a live widget
   exists, and is the cheapest way to exercise a panel without clicking.
4. `hyprctl layers` — confirms the panel's layer-shell surface exists.
5. `grim -o <monitor> shot.png` — settles "is it actually on screen".

### 6. Call external data and APIs

A plugin has no HTTP client of its own. Quickshell 0.3.x ships `Quickshell.Io`
(`Process`, `Socket`, `SocketServer`, `SplitParser`, `StdioCollector`,
`JsonAdapter`, `FileView`) and `Quickshell.Networking` (device/Wi-Fi state, not
HTTP). Three patterns cover what plugins actually do — pick by how much state
the call needs.

**1. `Process` + `curl` — one request, no helper.** This is what the built-in
weather panel does:

```qml
Process {
  id: forecastProc
  command: ["curl", "-fsS", "--max-time", "10",
            "https://wttr.in/" + root.locationQuery + "?format=j1"]
  stdout: StdioCollector {
    waitForEnd: true
    onStreamFinished: {
      var raw = String(text || "").trim()
      if (!raw) { root.scheduleRetry(); return }
      try { root.report = JSON.parse(raw) } catch (e) { root.scheduleRetry() }
    }
  }
}
```

`-fsS` plus `--max-time` is the house style. Always parse inside `try`, and
schedule a retry instead of leaving the widget blank.

**2. `Process` + a bundled helper script — when it is not one HTTP call.**
Querying a SQLite database, walking a directory, or using a service's own SDK
belongs in a script that ships beside the QML:

```qml
readonly property string scannerScriptPath:
  root.pathFromUrl(Qt.resolvedUrl("../scripts/usage_scanner.py"))

function pathFromUrl(url) {
  var value = String(url || "")
  return value.indexOf("file://") === 0
    ? decodeURIComponent(value.substring(7)) : value
}

Process {
  command: ["python3", root.scannerScriptPath, root.resolvePath(root.dbPath)]
  stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyUsage(text) }
  stderr: StdioCollector {
    waitForEnd: true
    onStreamFinished: function(t) {
      if (t && t.trim() !== "") console.warn("myplugin", t.trim())
    }
  }
  onExited: root.refreshing = false
}
```

`Qt.resolvedUrl()` yields a `file://` URL; strip and decode it before handing it
to a shell, or the spawn fails. Keep the script's contract JSON in / JSON out and
never exit non-zero for expected conditions — print an error object instead.

**3. `Process` + a shell helper — when credentials, caching or rate limits are
involved.** The flight-radar plugin's `opensky-fetch` is the reference:

- Credentials live in `~/.local/state/omarchy/settings/<plugin>.json`, written
  `chmod 600`; the helper re-reads them per run and the QML never touches them.
- Tokens cache under `$XDG_RUNTIME_DIR/<plugin>/` (`chmod 700`).
- **Errors are JSON with exit 0** — `{"error": "..."}`, and
  `{"limited": true, "retryAfter": <seconds>}` for rate limits — so the panel can
  render the reason instead of showing nothing.
- Every request carries a timeout; a hung helper freezes only its own `Process`,
  but the UI must still show the last good value.

**Cache the last good result on disk** (a small JSON file, read back with
`FileView`): a widget that renders instantly at shell start with zero spawns
beats one that flickers on every restart. Refresh from a `Timer` whose interval
comes from a setting, and debounce user-driven queries so a keystroke cannot
spawn a process each.

Never put an API key in `shell.json` (world-readable, and it ends up in bug
reports) and never inline one in QML. The helper file plus `0600` is the pattern
the marketplace expects.

**4. `Process` + a long-running daemon — push updates or a held connection.**
`ssandys.tonearm` is the reference implementation for this shape: a Python
daemon (`tonearmd`) runs as a **systemd user service started from the plugin
directory itself** (`ExecStart=%h/.config/omarchy/plugins/<id>/scripts/tonearmd`),
a small CLI (`tonearmctl`) is the plugin's only interface to it, and
`Service.qml` subscribes with a long-lived `Process`:

```qml
Process {
  id: relay
  command: [root.ctlPath, "subscribe"]   // one JSON state line per change
  stdout: SplitParser {
    onRead: function (line) {
      if (!line) return
      try { root.state = JSON.parse(line); root._attempt = 0 }
      catch (e) { /* a partial line is not worth tearing the connection down for */ }
    }
  }
  // A failed spawn never emits exited() — the process goes straight to
  // running=false without ever passing through true. onRunningChanged is the
  // only signal covering both a failed spawn and a normal exit.
  onRunningChanged: {
    if (!relay.running) {
      root.state = null
      backoff.interval = Model.nextRetryDelay(root._attempt)
      root._attempt += 1
      backoff.restart()
    }
  }
}
```

Two `Process` traps the tonearm author confirmed the hard way:

- **A failed spawn never emits `exited()`.** If you need to react to "it never
  started", use `onRunningChanged` (or both handlers).
- **`Process.command` assigned while the process is running is silently
  ignored.** Never reassign `command` on a live `Process` — stop it first, or
  spawn a detached one-shot with `Quickshell.execDetached(argv)` for
  fire-and-forget sends. Pass argv entries as separate array items, never a
  joined string, or a value with spaces arrives as one argument.

Always back off before respawning a subscribe loop: a daemon that is down makes
the CLI exit instantly, and respawning on exit without a delay is a fork loop.
On the service side, `StartLimitIntervalSec=0` stops systemd's start-rate limit
from leaving the daemon permanently `failed` after a burst of restarts — which
is worse than merely disconnected, because the bar then shows stale data and
nothing retries.

Ship the one-time setup as `setup.sh` at the repo root (document it in the README
and reference it from `manifest.json`'s description, as tonearm does):

- verify dependencies with the **system** interpreter —
  `/usr/bin/python -c 'import dbus_next'`, not whichever `python3` a version
  manager shadows, because the unit runs under the system interpreter;
- install the unit into `~/.config/systemd/user/`, then `systemctl --user
  daemon-reload` and enable/start it;
- offer a `--check` mode that reports whether the daemon is running *and*
  paired, so support questions have one command to run;
- refuse to run unless invoked from the installed plugin directory
  (`realpath` compare), so it cannot half-install from a git checkout.

A daemon is not a substitute for the plugin contract: the plugin still ships
`manifest.json` and its QML, and the daemon exists only because a QML plugin
cannot hold a Roon socket or survive a shell restart. Say so in the README, and
keep the daemon optional — the widget must render a useful "not set up /
disconnected" state without it.

### 7. Declare widget settings in the manifest

A bar widget can describe its settings, and the shell registers that description
with the bar widget registry — `shell.qml` builds
`{displayName, description, category, allowMultiple, defaults, settingsForm,
schema, pluginId, sourceDir, source, firstParty}` from `barWidget` and the
settings panel reads it from there:

```json
"barWidget": {
  "displayName": "OpenCode Usage",
  "category": "AI",
  "allowMultiple": false,
  "defaults": { "refreshIntervalSec": 900, "syncMode": "Off" },
  "schema": [
    { "key": "refreshIntervalSec", "type": "integer",
      "label": "Refresh interval (seconds)",
      "min": 30, "max": 3600, "step": 30, "defaultValue": 900 },
    { "key": "syncMode", "type": "enum", "label": "Synced aggregation",
      "options": ["Off", "On"], "defaultValue": "Off" }
  ]
}
```

- `schema` types seen in the wild: `integer`, `enum`, `path`, `string`, with
  `label`, `description`, `min`, `max`, `step`, `defaultValue`, `options`.
- `defaults` holds what the widget reads before the user sets anything; mirror
  each value in `schema[].defaultValue`.
- `settingsForm` names a first-party form (`"weatherSettings"`,
  `"spacerSettings"`). Leave it out unless cloning a widget that has one.
- `activation: "on-demand"` appears in several listings but is not read by the
  current shell — it is documentation, not behaviour.
- The values themselves still live in the widget's `shell.json` entry, which is
  what `setting("key", fallback)` reads; write them back with
  `bar.shell.updateEntryInline(id, entry)`, merging into the existing entry.

### 8. Plugin kinds beyond bar-widget

The workflow above is bar-widget centric; the other kinds have their own root
type and injected properties. All of them are loaded by the running shell — a
plugin never starts a second process.

| kind | entryPoints key | root item | injected | notes |
|---|---|---|---|---|
| `bar-widget` | `barWidget` | `BarWidget` | `bar`, `moduleName`, `settings` | the chip on the bar |
| `panel` | `panel` | `Panel` | `bar`, `moduleName`, `settings` | nested popup; add `ipcTarget` for IPC |
| `overlay` | `overlay` | `Item { visible: false }` | `shell`, `manifest`, `service`, `opened` | builds its own `PanelWindow` |
| `menu` | `menu` | `Item` | `shell` | receives a payload via `summon(id, payloadJson)` |
| `service` | `service` | `Item { visible: false }` | `shell`, `manifest`, `widgetSettings` | headless data/logic owner |
| `bar` | `bar` | your own bar | bar config | full bar replacement; only one active |

**One plugin may declare several kinds and share state between them.**
`omarchy-duolingo` ships `["bar-widget", "overlay", "service"]` with
`BarWidget.qml`, `Overlay.qml` and `Service.qml`. The wiring that makes it work:

```qml
// BarWidget.qml — the chip owns the UI, the service owns the data
readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
readonly property var userData: service ? service.userData : null
readonly property bool fetching: service ? service.fetching === true : false

// A service gets no `settings` injection: the widget pushes its settings in.
function injectPanel() {
  // ...
  if (root.service && "widgetSettings" in root.service)
    root.service.widgetSettings = root.settings
}

// The service can ask the UI to react (a timer fired, a streak is about to break).
Connections {
  target: root.service
  function onRequestPanelToggle() { root.togglePanel() }
}
```

- **Service** owns timers, polling and on-disk state. Expose plain properties
  (`userData`, `fetching`, `lastError`, `isStale`) plus signals, and let every
  surface read from it instead of fetching twice. Root is
  `Item { visible: false }` with `shell`, `manifest`, `widgetSettings`.
- **Overlay** roots are `Item { visible: false }` that build their own
  `PanelWindow` with `WlrLayershell` (`layer: Overlay`, `keyboardFocus:
  Exclusive`). `open(payloadJson)` resolves the focused screen, and
  `finishClose()` **must** call `shell.hide(<id>)` or the surface stays mapped.
  Payloads arrive from `omarchy-shell shell summon <id> '<json>'`.
- **Menu** roots are plain `Item`s with `shell`; entries come from a JSONC file
  (the built-in reads `$OMARCHY_PATH/default/omarchy/omarchy-menu.jsonc` plus a
  user override). `summon` carries the entry point, e.g.
  `{"initialMenu": "root"}`.
- **`keepLoaded: true`** (top-level manifest key) keeps a plugin's component
  alive between summons — used by `omarchy.menu`. Leave it out unless the
  plugin must keep state while closed.
- **A suite** is one repository exposing several plugins; the marketplace lists
  it as a source with `type: "suite"`. Keep each ID namespaced and independently
  installable.

### 9. Exercise the lifecycle

```bash
omarchy plugin list --json
omarchy-shell shell summon "$PLUGIN_ID" '{}'
omarchy-shell shell hide "$PLUGIN_ID"
```

Test the actual interaction surface: click, Escape, shell summon/hide, disable, re-enable, shell restart, rescan, and removal. A bar widget should show its ID, kind, and `enabled: true` in the JSON listing.

🔴 CHECKPOINT — that lifecycle run has to pass before the repository is
published. A plugin that only works until the first rescan is not publishable.

### 10. Prepare and publish

Before sharing, replace the clone ID, remove clone-only metadata, and keep the
repository root installable:

```text
custom-clock/
├── manifest.json
├── BarWidget.qml
├── Panel.qml        # only if the plugin has a popup
├── README.md
├── LICENSE
└── tests/           # optional; node --test against the pure helpers
```

The publishing gate is a public GitHub repository with the plugin at its root —
`manifest.json`, README with install **and** removal instructions, a license
file, documented external dependencies, a globally unique plugin ID outside
`omarchy.*` — and a commit that installs without maintainer-only context:

```bash
omarchy plugin add https://github.com/yourname/custom-clock.git --enable --yes
omarchy plugin update io.github.yourname.clock --yes
omarchy plugin remove io.github.yourname.clock --yes
```

🛑 STOP — do not open a marketplace issue until that install/update/remove
round-trip succeeds against the exact pushed commit. The issue is bound to that
commit, and a repository that only installs for its author cannot be listed.

### Submit to the marketplace

The marketplace is
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace)
(browse at omarchyplugins.com). It validates repository structure and Omarchy
Quattro compatibility, runs an Automated Security Baseline against the exact
commit, and publishes only after a maintainer applies `approved-and-verified`.

Two things beyond the gate above: plugin IDs are permanent and must be globally
unique (search the marketplace before choosing one), and one optional root
`preview.png` (≤50 MB / 40 MP — the build optimizes it) may ship with the repo.

🔴 CHECKPOINT — the issue *is* the listing request. Show the finished title and
body to the plugin owner, get explicit approval, and only then create it. Fix
problems by editing that same issue; duplicates are rejected.

Create the submission issue:

```bash
cat > /tmp/omarchy-plugin-submission.md <<'EOF'
### Repository URL

https://github.com/you/your-plugin

### Category

System

### Tags

bar, quickshell, system

### Suggest a missing tag

_No response_

### Maintainer notes

_No response_

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
EOF

gh issue create \
  --repo omacom/omarchy-plugin-marketplace \
  --title "[Plugin]: Your Plugin Name" \
  --body-file /tmp/omarchy-plugin-submission.md
```

What the validator enforces:

- Keep all six `###` headings in that order with the exact checklist text.
- One category, spelled exactly: `Appearance`, `Desktop`, `Developer Tools`,
  `Hardware`, `Kids`, `Productivity`, `System`, `Widgets`, `Other`.
- One to three tags: `ai`, `bar`, `education`, `games`, `hyprland`, `kids`,
  `launcher`, `media`, `power-management`, `quickshell`, `security`, `system`,
  `vpn`, `workspaces`.
- The title must start with `[Plugin]:`.

A validation comment and a security-baseline comment appear on the issue; only
a maintainer's `approved-and-verified` publishes the listing. If no bot comment
appears, edit the issue (title prefix, heading order, exact category and all
five checkboxes are the usual causes) — editing re-runs detection. Fix problems
in the same issue instead of opening a duplicate.

To publish a newer commit for an existing listing, use the
[verification form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml)
and give the exact 40-character SHA; the listed snapshot stays unchanged until
the new commit passes validation, the baseline and maintainer review.

When preparing a submission for someone else: read their manifest, README and
license first, pick the category and tags from the allowed values, and keep
every heading and checklist line intact. The owner-approval checkpoint above
applies to agent-prepared submissions too.

## Red Flags — STOP

- Starting `qs`/`quickshell` as a second process for an official Omarchy plugin.
- Inventing `plugin.json`, `runtime`, `entry`, an installer hook, or a systemd service instead of using `manifest.json`.
- Using an `omarchy.*` ID, copying an official ID, or keeping `omarchy.clonedFrom` in a published plugin.
- Editing packaged Omarchy source instead of cloning into `~/.config/omarchy/plugins/`.
- Adding symlinks or unsafe/non-relative entry paths.
- Enabling code before reviewing it. Plugins run unsandboxed inside `omarchy-shell` with the user's permissions.
- Copying an official example's repository URL, author, description, or identity unchanged.
- Reading `bar.layoutConfig` or `bar.clickTargets` from a QML binding — that is the binding-loop recipe.
- Debugging a "still broken" file without clearing `~/.cache/quickshell/qmlcache` first — a stale failed compile replays old errors and sends you chasing a type that actually resolves.
- Opening a marketplace submission before `omarchy plugin add <url> --enable --yes` succeeds against the pushed commit.

## Output Contract

When creating a plugin, return: the selected kind and why, the complete file tree, each changed file, exact validation commands, observed test steps, install/enable commands, and known version assumptions. If the request is actually for an independent Quickshell config, state that boundary and use a separate standalone workflow.
