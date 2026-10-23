# Writing a Bun plugin

The plugin runs in [Bun](https://bun.com): the host starts the Bun runtime `@arcships/rutis-bun`, and rows are named `bun:<module>`. Plugins are written as [TypeScript plugins](typescript-plugin.en.md) are (`definePlugin`, see the [plugin API](plugin-api.en.md)); the difference is that Bun runs them, so TypeScript needs no build.

## 1. Create a project

```bash
bunx --bun @arcships/rutis-host new greeter --lang bun
cd greeter
bun install
```

| File | Purpose |
| --- | --- |
| `src/index.ts` | The plugin |
| `test/index.test.ts` | Unit tests (`bun test`), no host needed |
| `rutis.dev.json` | Local runtime configuration and other plugins for testing |
| `package.json` | Depends on `@arcships/rutis`; dev dependencies `@arcships/rutis-bun`, `@arcships/rutis-host` |
| `tsconfig.json` | `bun run check` type checks: Bun runs TypeScript without checking types |
| `.github/workflows/publish.yml` | Tests and publishes to npm on a `v*` tag |

## 2. Write and test the plugin

Write it as in sections 2 and 3 of the TypeScript plugin guide. Tests use `bun test`:

```ts
import { expect, test } from 'bun:test'
import { load } from '@arcships/rutis/testing'
import plugin from '../src/index.ts'

test('greets', async () => {
  const t = await load(plugin, { config: { greeting: 'Hi' } })
  expect(await t.service('greeter').hello('Ada')).toBe('Hi, Ada!')
  await t.unload()
})
```

Without the SDK, a module can also export `apply(ctx, config)` directly, with `inject`, `provides` (optional, each method `'sync'` or `'async'`) and `config` (a JSON Schema). `provides` may be left out: what `ctx.provide` provides reaches rutis by itself, its methods the object's functions, called as `async`, by the same rules as on Node (see [Plugin API](plugin-api.en.md)).

### Events

As for TypeScript plugins ([TypeScript plugins: events](typescript-plugin.en.md#events)): `ctx.on` listens, `ctx.emit` / `ctx.parallel` / `ctx.serial` / `ctx.waterfall` / `ctx.bail` emit, `ctx.filter` picks listeners. Listeners register themselves with the host: events emitted by Node, Python and Go plugins and by Rust code in the host reach listeners in Bun too, and the other way round. On unload the row's `ctx.signal` is aborted and its running listeners are waited for.

```ts
import { definePlugin } from '@arcships/rutis'

export default definePlugin({
  apply(ctx) {
    ctx.on('greeting/pick', (lang: string) => (lang === 'sv' ? 'Hej' : undefined))   // undefined when there is no result
    ctx.on('greeting/format', async (text: string, next: () => Promise<string>) => `${await next()}!`)
    ctx.provide('greeter', {
      async hello(name: string, lang: string) {
        const word = (await ctx.serial<string>('greeting/pick', lang)) ?? 'Hello'
        const text = await ctx.waterfall<string>('greeting/format', `${word}, ${name}`, (text: string) => text)
        ctx.emit('greeting/said', name)                                               // returns at once
        return text
      },
    })
  },
})
```

Tests use the same test tool and run with `bun test` as usual; `host()` puts several plugins on one bus:

```ts
import { expect, test } from 'bun:test'
import { host } from '@arcships/rutis/testing'
import plugin from '../src/index.ts'

test('greets through events', async () => {
  const h = host()
  const t = await h.load(plugin)
  expect(await t.service('greeter').hello('Ada', 'sv')).toBe('Hej, Ada!')
  expect(await h.serial('greeting/pick', 'en')).toBeUndefined()
  await h.unload()
})
```

## 3. Run it in a host

```bash
bunx --bun rutis-host dev
```

`rutis-host dev` runs the project in Bun when it finds `bun.lock`, `runtimes.bun` in `rutis.dev.json`, or a dependency on `@arcships/rutis-bun`, and reloads it when files change.

A host's `rutis.json`:

```json
{
  "runtimes": { "bun": { "project": "." } },
  "rows": [
    { "id": "greeter", "name": "bun:greeter" },
    { "id": "report", "name": "bun:./report.ts", "inject": ["greeter"] }
  ]
}
```

- `bun:<npm name or subpath>` resolves from the `node_modules` of `project`; `bun:./path` is relative to `project`. The row `bun:sqlite` names the project's module `sqlite`, not Bun's built-in `bun:sqlite`.
- Fields of `runtimes.bun`: `project` (default `.`), `runtime` (where `@arcships/rutis-bun` is; by default the project's), `program` (the Bun executable; by default `bun` on `PATH`).
- It can be configured together with `runtimes.node` and `runtimes.py`; services are shared across runtimes by name.

## 4. What the runtime promises

- **Only what the project installed**: the runtime always starts with `--no-install`; a missing package makes loading fail and is never downloaded. Install plugins and their dependencies with `bun add`. By default `bun install` runs install scripts only for dependencies on Bun's built-in trusted list; a project's `trustedDependencies` **replaces** that list, so list only the packages whose install scripts are needed.
- **No `.env`**: the runtime starts with `--no-env-file`, so the environment comes only from the host. The project's `bunfig.toml` applies (including `preload`), as the project's own trusted configuration.
- **Re-entrant synchronous calls**: while a plugin's synchronous call into rutis waits, other calls into this runtime still run. A plugin's service may therefore be called during its own synchronous call: do not hold a lock across a call into rutis.
- **An uncaught error ends the process**, withdrawing every service of the runtime.
- **Reloading** imports the plugin module itself again; the modules it imports are replaced only by restarting the runtime.
- **Packages installed while the runtime runs** (`bun add`) are found only after the runtime restarts: a Bun process remembers that a package was missing.

## 5. Publish

As for TypeScript plugins: `npm publish` (the template's workflow publishes on a `v*` tag). A host installs it with `bun add` and adds a row `{ "id": "greeter", "name": "bun:greeter" }`.

## 6. Run on another machine

A Bun runtime can also run on another machine, its plugins managed by rutis elsewhere, in either direction (see [Connect nodes](nodes.en.md)):

```bash
# Listen, and rutis connects (on the rutis side: a node row and runtimes.remote with language bun)
RUTIS_TOKEN=secret RUTIS_CERT=server.pem RUTIS_KEY=server.key \
  bun --no-install --no-env-file node_modules/@arcships/rutis-bun/src/main.ts listen:wss://0.0.0.0:7443/rutis --id edge --peer main .
# Dial out to a rutis access point (on the rutis side: runtimes.remote with listen and instances)
RUTIS_TOKEN=secret RUTIS_CA=ca.pem \
  bun --no-install --no-env-file node_modules/@arcships/rutis-bun/src/main.ts dial:wss://main.example.com:7443/rutis --id worker-1 --peer main .
```

- Plugins are resolved from the last argument, the project directory; rows are named `<runtime-name>:<module>`, such as `edge:greeter` or `edge:./report.ts`.
- Each session runs in a child runtime process: when the session ends (a disconnect, a newer connection taking over) it unloads every row and exits, and the next session starts a new process.
- Dialing out reconnects by fixed rules and reports its state on stderr (`rutis: connected to …` and so on); SIGTERM or Ctrl-C unloads every row and exits. The rules are in [Connect nodes](nodes.en.md#runtimes-that-connect-in). `RUTIS_CA` is trusted together with the roots Bun trusts by default.

## Environment

Bun 1.4 or later. Windows is not tested yet.
