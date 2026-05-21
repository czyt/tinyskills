---
name: d2lang
description: Use when creating, validating, exporting, embedding, or automating D2/D2Lang diagrams, .d2 files, diagram-as-code architecture diagrams, CLI watch/render workflows, CI exports, or Go/Node programmatic diagram generation.
---

# D2Lang Diagram Workflow

## Overview

D2 is a declarative diagram language. Default to generating a `.d2` source file, then use the D2 CLI to validate, format, watch, and export. For automation, treat the CLI as the stable rendering API; use the Go `d2oracle` API only when you need AST/graph edits.

## Workflow

1. Check the toolchain before rendering or promising exact flags:
   ```bash
   d2 version
   d2 --help
   ```
   If D2 is missing, do not install silently. Show the official dry run first:
   ```bash
   curl -fsSL https://d2lang.com/install.sh | sh -s -- --dry-run
   # If the user accepts the commands:
   curl -fsSL https://d2lang.com/install.sh | sh -s --
   # or from source:
   go install oss.terrastruct.com/d2@latest
   ```
2. Clarify only when the choice changes the artifact: output format, destination path, diagram type, or whether an install/network action is allowed. Otherwise choose SVG, `elk` for architecture if available, and local files.
3. Write D2 with stable keys and human labels. Connections reference keys, not labels.
4. Validate and format before claiming the diagram works:
   ```bash
   d2 validate input.d2
   d2 fmt input.d2
   ```
5. Render with explicit output and check the exit status. Never use output-file existence as success proof; D2 can write partial renders after errors.
6. For interactive editing, use watch mode:
   ```bash
   d2 -w input.d2 out.svg
   d2 -w --host localhost --port 8080 --browser 0 input.d2 out.svg
   ```

## Quick Reference

| Need | Command or pattern |
| --- | --- |
| SVG export | `d2 input.d2 out.svg` |
| Default SVG | `d2 input.d2` creates `input.svg` |
| PNG/PDF/PPTX/GIF/TXT | `d2 input.d2 out.png` etc.; confirm supported formats with `d2 --help` |
| stdin to SVG stdout | `echo "x -> y" \| d2 - - > out.svg` |
| stdout format | `d2 input.d2 --stdout-format png - > out.png` |
| Layouts | `d2 layout`, `d2 layout elk`, `d2 --layout elk input.d2 out.svg` |
| Themes | `d2 themes`, `d2 --theme 300 --dark-theme 200 input.d2 out.svg` |
| Web playground | `d2 play input.d2` |
| CI check | `d2 validate input.d2 && d2 fmt --check input.d2 && d2 input.d2 out.svg` |
| Duplicate SVGs in one HTML page | `d2 --salt unique-id input.d2 out.svg` |
| Direct HTML embedding | `d2 --no-xml-tag input.d2 out.svg` |

PNG/PDF exports need browser rendering. In headless CI, `failed to launch Chromium` usually means Playwright dependencies are missing:
```bash
npm install -g @playwright
npx playwright install --with-deps chromium
```

## Core Syntax

```d2
vars: {
  d2-config: {
    layout-engine: elk
    theme-id: 300
    dark-theme-id: 200
    pad: 40
  }
}

direction: right

client: Client {
  shape: person
}

api: HTTP API {
  shape: package
  router: Router
  handlers: Handlers
}

db: PostgreSQL {
  shape: cylinder
}

client -> api.router: HTTP request
api.router -> api.handlers: route
api.handlers -> db: SQL query
db -> api.handlers: rows
api.handlers -> client: JSON response
```

Important syntax rules:
- `x -> y: label` declares two shapes and a labeled connection.
- Shape labels can differ from keys: `pg: PostgreSQL`.
- Use keys in connections: `pg -> api`, not `PostgreSQL -> API`.
- Containers use dots or nested maps: `cloud.aws.api` or `cloud: { aws: { api } }`.
- Common shapes: `rectangle`, `person`, `cylinder`, `cloud`, `queue`, `package`, `hexagon`, `diamond`, `sql_table`, `sequence_diagram`.
- SQL tables use `shape: sql_table`; row constraints include `primary_key`, `foreign_key`, and `unique`.
- Sequence diagrams are ordinary D2 objects with `shape: sequence_diagram`; ordering matters inside them.
- Icons accept URLs or local files with the CLI: `icon: ./service.svg`.

## Configuration

Diagram-local config lives under `vars.d2-config`:
```d2
vars: {
  d2-config: {
    layout-engine: elk
    theme-id: 4
    dark-theme-id: 200
    sketch: true
    center: true
    pad: 0
  }
}
```

CLI flags and environment variables override `vars.d2-config`. Use this deliberately in CI:
```bash
D2_LAYOUT=elk D2_THEME=4 d2 input.d2 out.svg
```

Layout caveats:
- `dagre` is default and fast for hierarchical graphs.
- `elk` is often better maintained and supports exact SQL row connections.
- `tala` is designed for software architecture diagrams, but may not be bundled in a local install. Check `d2 layout` before recommending it; fall back to `elk` when unavailable.
- Layout-specific features vary. Check `d2 layout` and `d2 layout <engine>` before using `near`, locked positions, container width/height, or ancestor-to-descendant edges.

## Failure Handling

| Symptom | Action |
| --- | --- |
| `d2: command not found` | Provide install dry-run, then ask/confirm before install side effects |
| `failed to launch Chromium` | Install Playwright Chromium dependencies or switch to SVG |
| Render exits non-zero but output exists | Treat as failure; read stderr and fix the D2 source |
| Layout flag rejected | Run `d2 layout`; choose one of the installed engines |
| SVG looks wrong in design tools | Prefer browser/web embedding; D2 SVG can use CSS and `foreignObject` for Markdown |
| Multiple embedded SVGs conflict | Add a stable `--salt` per diagram |

## Programming Use

Prefer CLI stdin/stdout for language-neutral generation:
```bash
printf '%s\n' 'x -> y: generated' | d2 - - > generated.svg
```

Go wrapper:
```go
func RenderD2SVG(ctx context.Context, src string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "d2", "-", "-")
	cmd.Stdin = strings.NewReader(src)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("d2 render failed: %w: %s", err, stderr.String())
	}
	return stdout.Bytes(), nil
}
```

Node wrapper:
```js
import { execFileSync } from "node:child_process";

const source = "x -> y: generated\n";
const svg = execFileSync("d2", ["-", "-"], { input: source });
```

Direct Go API boundary:
- Official docs expose `d2/d2oracle` for programmatic graph edits in Go.
- Its functions are pure: keep the returned graph from each call.
- Main operations are `Create`, `Set`, `Delete`, `Rename`, `Move`, plus ID delta helpers.
- Use it for bidirectional editing, stored graph state, or ID tracking; use the CLI for ordinary rendering/export.

## Response Pattern

For user-facing answers, include:
- The `.d2` source as a named file.
- The validation and render commands.
- Any layout/theme assumptions and how to discover alternatives.
- CI/runtime caveats only when relevant to the requested output format.

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Checking only that `out.svg` exists | Check `d2` exit status; partial output may exist on errors |
| Connecting labels instead of keys | Define stable keys and connect those keys |
| Assuming PNG/PDF works in minimal CI | Install Playwright/Chromium dependencies or export SVG |
| Hardcoding a layout feature everywhere | Confirm support with `d2 layout <engine>` |
| Using `d2oracle` just to render | Use CLI stdin/stdout unless you need graph mutation APIs |
| Forgetting config precedence | CLI flags/env vars override `vars.d2-config` |

## Official References

These pages were captured from `https://d2lang.com` with Firecrawl while creating this skill:
- Tour and hello world: `https://d2lang.com/tour/intro`, `https://d2lang.com/tour/hello-world`
- Install and CLI manual: `https://d2lang.com/tour/install`, `https://d2lang.com/tour/man`
- Exports: `https://d2lang.com/tour/exports`
- Layouts, themes, syntax: `https://d2lang.com/tour/layouts`, `https://d2lang.com/tour/themes`, `https://d2lang.com/tour/shapes`, `https://d2lang.com/tour/connections`, `https://d2lang.com/tour/containers`
- Special diagrams and assets: `https://d2lang.com/tour/sql-tables`, `https://d2lang.com/tour/sequence-diagrams`, `https://d2lang.com/tour/icons`
- Programmatic graph API: `https://d2lang.com/tour/api`
