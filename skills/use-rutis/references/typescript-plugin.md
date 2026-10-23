# Write a TypeScript Plugin

This guide covers creating a project, publishing it, and using it from a host. JavaScript uses the same approach without the types.

## 1. Create a project

<!-- example: typescript-en run -->
```bash
npx @arcships/rutis-host new greeter --lang node
cd greeter
npm install
```

The generated project contains:

| File | Purpose |
| --- | --- |
| `src/index.ts` | The plugin itself. |
| `test/index.test.ts` | Unit tests that do not need a host. |
| `rutis.dev.json` | Local runtime configuration and other plugins used for testing. |
| `package.json` | Depends on `@arcships/rutis`; development dependencies include `@arcships/rutis-host` and `@arcships/rutis-runtime`. |
| `.github/workflows/publish.yml` | Tests and publishes to npm when a `v*` tag is pushed. |

## 2. Write the plugin

<!-- example: typescript-en file=greeter/src/index.ts -->
```ts
import { definePlugin } from '@arcships/rutis'

export interface Config {
  city?: string
}

interface Llm {
  ask(question: string): Promise<string>
}

class Weather {
  constructor(private readonly llm: Llm, private readonly city: string) {}

  async today(): Promise<string> {
    return `${await this.llm.ask(`weather in ${this.city}`)} in ${this.city}`
  }
}

export default definePlugin<Config>({
  inject: ['llm'],                                 // Services used: start when all are ready; stop if any is revoked
  config: { type: 'object', properties: { city: { type: 'string' } } },  // Configuration JSON Schema
  apply(ctx, config) {
    ctx.provide('weather', new Weather(ctx.use<Llm>('llm'), config.city ?? 'Oslo'))
    return () => {}                                // Cleanup; ctx.effect(cleanup) also works, or return nothing
  },
})
```

The plugin depends only on `@arcships/rutis`. It does not need to know which host runs it, which language or machine provides `llm`, or when it starts and stops; the host decides those things. See [Plugin API](plugin-api.en.md) for capabilities and value passing rules.

`weather` needs no declaration: what `ctx.provide` provides reaches rutis by itself, its methods the object's functions (here `today`), called as `async`. To mark a method `sync`, or to let `rutis-host check` know before running what the plugin provides, add `provides`, such as `provides: { weather: { unit: 'sync' } }` (a declared service offers only its declared methods).

## 3. Test

`@arcships/rutis/testing` provides fake services and calls the services provided by the plugin without requiring a host:

<!-- example: typescript-en file=greeter/test/index.test.ts -->
```ts
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { load } from '@arcships/rutis/testing'
import plugin from '../src/index.ts'

test('reports the weather of the configured city', async () => {
  const t = await load(plugin, {
    config: { city: 'Oslo' },
    services: { llm: { ask: async () => 'sunny' } },
  })
  assert.equal(await t.service('weather').today(), 'sunny in Oslo')
  await t.unload()
})
```

<!-- example: typescript-en run -->
```bash
npm test
```

`load` checks the same things as the host: the plugin uses only services declared in `inject`; its provided service has every method declared in `provides` (an undeclared service is called as rutis calls it, by the object's methods, all async; `t.methods(name)` returns the methods rutis sees); and all cleanup functions run when it unloads. In strict mode (the default), values follow cross-process rules: data is copied, functions and objects with methods are passed by reference, and a method declared `sync` cannot return a Promise. Code that works only within one process fails here.

### Events

`ctx.on(name, listener)` listens to an event; `ctx.emit`, `ctx.parallel`, `ctx.serial`, `ctx.waterfall` and `ctx.bail` are the five ways to emit. Listeners register themselves with the host and nothing is declared: whether the emitter is another plugin in the same process, a plugin in another language, Rust code in the host or a linked node, the result is the same. The full rules are in [plugin API: events](plugin-api.en.md#events).

The two plugins below share one bus on the test tool's `host()`: `greeter` takes the first result with `serial`, lets other plugins rewrite the greeting with `waterfall` and notifies with `emit`; `shout` is a link of the waterfall and listens to the notification.

<!-- example: typescript-en file=greeter/test/events.test.ts order=2 -->
```ts
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { definePlugin } from '@arcships/rutis'
import { host } from '@arcships/rutis/testing'

const greeter = definePlugin({
  apply(ctx) {
    // undefined / null / false is "no result": serial asks the next listener
    ctx.on('greeting/pick', (lang: string) => (lang === 'sv' ? 'Hej' : undefined))
    ctx.provide('greeter', {
      async hello(name: string, lang: string) {
        const word = (await ctx.serial<string>('greeting/pick', lang)) ?? 'Hello'
        // every argument is the event's; `with` gives the terminal, the innermost end of the chain
        const text = await ctx.waterfall.with((text: string) => text)<string>('greeting/format', `${word}, ${name}`)
        ctx.emit('greeting/said', name)                  // returns at once, waits for no listener
        return text
      },
    })
  },
})

const said: string[] = []
const shout = definePlugin({
  apply(ctx) {
    // a waterfall listener gets next last: it runs the rest of the chain
    ctx.on('greeting/format', async (text: string, next: () => Promise<string>) => `${await next()}!`)
    ctx.on('greeting/said', (name: string) => { said.push(name) })
  },
})

test('plugins hear each other', async () => {
  const h = host()
  const t = await h.load(greeter)
  await h.load(shout)
  assert.equal(await t.service('greeter').hello('Ada', 'sv'), 'Hej, Ada!')
  assert.equal(await t.service('greeter').hello('Bo', 'en'), 'Hello, Bo!')
  assert.deepEqual(said, ['Ada', 'Bo'])
  assert.equal(await h.serial('greeting/pick', 'sv'), 'Hej')   // the test can emit too
  await h.unload()
})
```

- `emit` returns at once; a failing listener reaches neither the emitter nor the other listeners and is reported in one line where it runs (in a test, in `h.reported` / `t.reported`). To wait for every listener and get their errors, use `await ctx.parallel(...)`: failures are an `AggregateError` in registration order.
- `waterfall` returns a Promise whenever a listener is in another process, so always `await` it. `bail` is a synchronous `serial`; an `async` listener fails it with `AsyncListener`.
- `ctx.filter(d => d.row === 'audit').parallel(...)` delivers only to the listeners the filter keeps; `ctx.on(name, fn, { prepend: true })` goes first, `{ global: true }` is exempt from filters.
- Scopes: `h.load(plugin, { scope: 't1/s1' })` loads a plugin into an instance, `h.at('t1/s1').emit(...)` emits from there; a listener receives only the events emitted in its scope and inside it.
- On unload the plugin's `ctx.signal` is aborted and its running listeners are waited for (up to the shutdown deadline) before the cleanups run.

The `t` that `load(plugin)` returns has the five methods and `filter` too, emitting from that plugin's scope. For a plugin in another language listening to an event a TypeScript plugin emits, see [Python plugins: events](python-plugin.en.md#events).

## 4. Run in a local host

<!-- example: typescript-en run until="greeter: running" order=99 -->
```bash
npx rutis-host dev
```

`dev` runs this project as a row using the source file `src/index.ts`, without a build, and reloads it when files change. Add other required services to `rutis.dev.json`, such as a fake `llm`:

<!-- example: typescript-en file=greeter/rutis.dev.json -->
```json
{
  "rows": [
    { "id": "greeter", "config": { "city": "Oslo" } },
    { "id": "llm", "name": "./dev/fake-llm.ts" }
  ]
}
```

<!-- example: typescript-en file=greeter/dev/fake-llm.ts -->
```ts
// dev/fake-llm.ts
import { definePlugin } from '@arcships/rutis'
export default definePlugin({
  provides: { llm: { ask: 'async' } },
  apply(ctx) { ctx.provide('llm', { ask: async () => 'sunny' }) },
})
```

The row with the same ID as the plugin supplies its configuration; the other rows are additional plugins to run. `npx rutis-host check` lists each row's dependencies, provided services, and configuration schema, and exits with a nonzero status if there is a problem. It is suitable for CI.

## 5. Publish

```bash
npm run build      # tsc generates dist/
npm publish
```

Alternatively, push a tag such as `v0.1.0`. The generated workflow tests, runs `check`, and publishes (the repository needs an `NPM_TOKEN` secret).

Declare a version range such as `"@arcships/rutis": "^0.13.0"`. The plugin is tagged with its plugin API version (`definePlugin` adds this automatically). If the host runtime is older, it reports the problem clearly instead of failing later during execution.

## 6. Use from a host

Install the plugin in the host's Node project, alongside `@arcships/rutis-runtime`, then add a row named after the package:

```bash
npm install greeter
```

```json
{ "id": "greeter", "name": "greeter", "config": { "city": "Oslo" } }
```

See [rutis-host and rutis.json](rutis-host.en.md), or [Embed in a Rust application](rust-host.en.md) for a Rust host.

## Existing Cordis plugins

No rewrite is needed, and no change to the package: name the package in a row of `rutis.json` (a published package as well):

```json
{ "id": "storage", "name": "@deepseek-ai/dsh-storage" }
```

The plugin runs in the Node runtime's Cordis Context, in the same process as leaf plugins and other Cordis rows: rows of the same runtime use each other's services by Cordis's native rules and receive the objects themselves. The services it provides reach rutis by themselves, and other runtimes and Rust use them by name; the methods are the functions of the service object, called as `async`. To mark some methods `sync`, or to let `rutis-host check` know before running what it provides, declare them in the package's `package.json` (a declaration applies when present):

```json
"rutis": { "provides": { "weather": { "today": "sync" } } }
```

For name clashes and what `check` reports, see [Cordis](cordis.en.md).
