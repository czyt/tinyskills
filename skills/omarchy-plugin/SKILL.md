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
| `X is not a type` where X is a QtQuick.Controls type (`ScrollBar`, `Control`, `Label`) | The Controls style module is not loaded for user plugins. Redraw it or use `qs.Ui` — see Platform pitfalls. |
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

**QtQuick.Controls types do not resolve in a user plugin.**

```text
Plugin widget io.github.you.plugin failed: BarWidget.qml:307:5: Type TrayMenuList unavailable
TrayMenuList.qml:262:7: ScrollBar is not a type
```

`import QtQuick.Controls` parses, but the type itself lives in the Controls
style module (`QtQuick.Controls.Basic`), which the shell does not load for user
plugins. Built-in widgets can use it because they are compiled inside the shell
— a plugin cannot rely on that. Verified dead ends: adding
`import QtQuick.Controls.Basic`, adding `import qs.Ui`, and moving
`import Quickshell` to the top all still fail. Redraw the affordance with
`Rectangle` + theme tokens, or use a `qs.Ui` component that already wraps it.

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

### 6. Exercise the lifecycle

```bash
omarchy plugin list --json
omarchy-shell shell summon "$PLUGIN_ID" '{}'
omarchy-shell shell hide "$PLUGIN_ID"
```

Test the actual interaction surface: click, Escape, shell summon/hide, disable, re-enable, shell restart, rescan, and removal. A bar widget should show its ID, kind, and `enabled: true` in the JSON listing.

🔴 CHECKPOINT — that lifecycle run has to pass before the repository is
published. A plugin that only works until the first rescan is not publishable.

### 7. Prepare and publish

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

🛑 STOP — never open a marketplace issue before `omarchy plugin add <url>
--enable --yes` succeeds against the exact pushed commit, on a machine with no
maintainer-only context. The issue is bound to a commit; a repository that only
installs for its author cannot be listed.

The publishing gate is a public GitHub repository, valid root `manifest.json`,
README with install **and** removal instructions, a license file, and a
validated current commit:

```bash
omarchy plugin add https://github.com/yourname/custom-clock.git --enable --yes
omarchy plugin update io.github.yourname.clock --yes
omarchy plugin remove io.github.yourname.clock --yes
```

### Submit to the marketplace

The marketplace is
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace)
(browse at omarchyplugins.com). It validates repository structure and Omarchy
Quattro compatibility, runs an Automated Security Baseline against the exact
commit, and publishes only after a maintainer applies `approved-and-verified`.

Repository requirements: public GitHub repo, plugin at the **root**, root
`manifest.json`, root README with install and removal instructions, root
license file, documented external dependencies, globally unique plugin ID
outside `omarchy.*` (IDs are permanent — search the marketplace first), and
optionally one root `preview.png` (≤50 MB / 40 MP; the build optimizes it).

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
license first, pick the category and tags from the allowed values, keep every
heading and checklist line intact, show the finished title and body to the
owner, and only create the issue after the owner explicitly approves it.

## Red Flags — STOP

- Starting `qs`/`quickshell` as a second process for an official Omarchy plugin.
- Inventing `plugin.json`, `runtime`, `entry`, an installer hook, or a systemd service instead of using `manifest.json`.
- Using an `omarchy.*` ID, copying an official ID, or keeping `omarchy.clonedFrom` in a published plugin.
- Editing packaged Omarchy source instead of cloning into `~/.config/omarchy/plugins/`.
- Adding symlinks or unsafe/non-relative entry paths.
- Enabling code before reviewing it. Plugins run unsandboxed inside `omarchy-shell` with the user's permissions.
- Copying an official example's repository URL, author, description, or identity unchanged.
- Using a `QtQuick.Controls` type (e.g. `ScrollBar`) in a user plugin — it will not resolve; see Platform pitfalls.
- Reading `bar.layoutConfig` or `bar.clickTargets` from a QML binding — that is the binding-loop recipe.
- Debugging a "still broken" file without clearing `~/.cache/quickshell/qmlcache` first.
- Opening a marketplace submission before `omarchy plugin add <url> --enable --yes` succeeds against the pushed commit.

## Output Contract

When creating a plugin, return: the selected kind and why, the complete file tree, each changed file, exact validation commands, observed test steps, install/enable commands, and known version assumptions. If the request is actually for an independent Quickshell config, state that boundary and use a separate standalone workflow.
