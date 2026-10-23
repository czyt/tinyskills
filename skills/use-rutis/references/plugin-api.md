# Plugin API

TypeScript / JavaScript plugins (`@arcships/rutis`), Python plugins (`rutis`) and Go plugins (`github.com/arcships/rutis/go/rutis`, see [Go plugins](go-plugin.en.md)) use the same conventions; so do Swift plugins (the Swift package `Rutis` of this repository, see [Swift plugins](swift-plugin.en.md)), and Kotlin plugins (`io.github.arcships:rutis`, K-P1: the desktop jvm target and the testing tool, applications connecting in K-P2, see [kotlin/README](../../kotlin/README.md)). The current plugin API version is **3**.

## Declarations

| Declaration | TypeScript (`definePlugin({...})`) | Python (`define_plugin(apply, ...)` or module variable) | Go (`rutis.Define(rutis.Plugin[C]{...})`) | Swift (`Rutis.define(Plugin(...))`) | Kotlin（`Rutis.define<C>(...) { ctx, config -> }`） | Meaning |
| --- | --- | --- | --- | --- | --- | --- |
| Services used | `inject: ['llm']` | `inject=["llm"]` | `Inject: []string{"llm"}` | `inject: ["llm"]` | `inject = listOf("llm")` | The plugin starts when all are ready. If any is revoked, the plugin stops and waits for it to return. |
| Services provided (optional) | `provides: { weather: { today: 'sync' } }` | `provides={"weather": Weather}` or `{"weather": {"today": "sync"}}` | `Provides: rutis.Provides{"weather": rutis.MethodsOf[*Weather](rutis.Sync("Unit"))}` (exported methods, `async` unless `Sync` names them) | `provides: ["weather": .of(Weather.self, sync: ["unit"])]` (the methods of a `@RutisService` type, `async` unless `sync` names them) | `provides = mapOf("weather" to service<Weather>(sync = setOf("unit")))` (the public member functions of a `@RutisService` class, `async` unless `sync` names them) | Not needed: what `ctx.provide` provides reaches rutis by itself (see below). When present it applies: it marks methods `sync` and lets `rutis-host check` know before running who provides what; a declared service offers only its declared methods. |
| Configuration | `config: { type: 'object', ... }` | `config={...}` (module variable: `Config`) | the type `C` (schema derived from it), or `Schema` | the `Decodable` type of `config:` (schema from `@RutisConfig`, or `static let rutisSchema`) | the `@Serializable` type `C` (schema derived from its `SerialDescriptor`), or `schema` | JSON Schema used by the host to validate and display configuration. |
| Startup | `apply(ctx, config)` | `apply(ctx, config)` | `Apply: func(ctx *rutis.Ctx, config C) error` | `apply: { ctx, config in ... }` (`async throws`) | `{ ctx, config -> }`, may suspend; an exception fails the load | May be async; returns a cleanup function or nothing (Go: an error fails the load). |

## `ctx`

| Method | Purpose |
| --- | --- |
| `ctx.use(name)` | Gets a service declared in `inject`. A service provided by a plugin in the same runtime process is the object itself; services from other processes, languages, or machines are proxies. |
| `ctx.provide(name, value)` | Provides a service until the plugin is unloaded or the returned function is called. It reaches rutis by itself, used by name from other languages and processes; when `provides` does not declare it, its methods are the public methods of `value` (JavaScript: its own and its prototype chain's functions, not `constructor`; Python: callable attributes not starting with `_`; Go: exported methods), all called as `async`; fields are not methods. The inferred methods follow each language's rules, so the same service written in two languages can differ: a JavaScript class extending `EventEmitter` also exposes `on`, `emit` and the rest; list the methods in `provides` to expose only those. |
| `ctx.effect(cleanup)` | Runs `cleanup` when the plugin is unloaded. It may be async. |
| `ctx.on(name, listener, options?)` | Listens to an event: wherever it is emitted (another plugin, another runtime, the host, a linked node), it reaches `listener` when the emitter is in this plugin's scope or inside it. Unregistered when the plugin unloads; the returned function unregisters it at once. See [Events](#events) below. |
| `ctx.emit` / `parallel` / `serial` / `waterfall` / `bail` | The five ways to emit; `ctx.filter(keep)` gives the same five methods delivering to some listeners only. See [Events](#events). |
| `ctx.signal` | (JavaScript) Aborted when the plugin unloads; Python cancels the task, in Go it is `ctx` itself. |

An error that crossed a session and is thrown on crosses again with its whole error graph (causes, an `AggregateError`'s children) on Node, Bun, Python and Go, not only inside an aggregate: Node decodes it into a real `Error` whose re-encoding carries the whole graph, and Python's `encode_error` and Go's `encodeError` splice a `RemoteError`'s graph in (nodes appended, references shifted) to match.

Cleanups run in reverse registration order: the function returned by `apply` runs first, followed by functions registered with `ctx.effect`.

In Go: `ctx.Use(name, &target)` binds the service to a struct of function fields (or a `*rutis.Service`); `ctx.Provide(name, value)`; `ctx.Effect(func(context.Context) error)`; `ctx.Go(task)` runs a goroutine stopped at unload. `*rutis.Ctx` is a `context.Context` cancelled when the plugin unloads.

In Kotlin: `ctx.use<I>(name)` uses the service through the `@RutisClient` interface `I` (the provider's own object when one in this process implements `I`); `ctx.provide(name, obj)` takes an instance of a `@RutisService` class, whose method table the KSP processor generates at compile time; `ctx.effect { }`; `ctx` is a coroutine scope cancelled when the plugin unloads, and coroutines started with `ctx.launch { }` are cancelled and waited for then. A received error is a `RutisException`, matched by `name`.

Rust plugins in the host (built in, or dylib plugins): add `#[rutis::service]` to the service type's `impl` block, and once `ctx.provide(value)` provides it, it reaches other languages by name (by default the type's name, first word lowercased); rows of every language call it with `ctx.use(name)`. Unmarked Rust types are not served. See [Rust host](rust-host.en.md#mark-the-type-rutisservice).

## Events

Every listener on a host — of the host's Rust plugins, of every plugin in every runtime process (any language), of what node links bring in — is on **one logical bus**. There is one rule:

> Wherever an event is emitted and wherever its listeners are, the result is the same as if every listener were in one process.

The only exceptions are what is physically impossible (a cycle of synchronous waits, waiting synchronously on a far end that went away); those fail with an error and never silently turn into something else. Design: [unified events](../design-events-2026-10-18.en.md); wire protocol: [protocol spec](../design-events-protocol-2026-10-18.en.md).

- **Registration is automatic**: a plugin writes `ctx.on(name, listener)` as usual and declares nothing, neither in `rutis.json` nor in the host's Rust code. A runtime registers its listeners with the host, as services reach rutis by themselves.
- **An event is a name, arguments and a scope**. The name is a string, the same in every language and on every path, by convention `area/verb` (`session/created`). Arguments cross as in [passing values](#passing-values). The scope is the loader instance the emitter is in (below).
- **One listener table**: a listener registered once can be called by any of the modes below; the emitter chooses the mode.
- **Through the host only when needed**: when every listener of a name is in the emitter's process, the dispatch runs in that process without the host; the results are the same, only where the code runs differs.

### The five modes

| Mode | The emitter gets | Order | Return values | A listener fails |
| --- | --- | --- | --- | --- |
| `emit` | Returns at once, waits for nothing | Starts every listener in registration order; events of one emitter and one name reach each listener in emission order | Ignored | Reaches neither the emitter nor the other listeners; reported in one line where the listener runs (see [reported failures](#reported-failures)); never ends a process |
| `parallel` | Waits for all | Starts them in registration order; asynchronous parts overlap | Ignored | All run to the end; failures are thrown as an `AggregateError` with the failures in **registration order** (not completion order), even when only one failed |
| `serial` | The first return value that is a result, or no result | One at a time in registration order | The first result stops the dispatch and is returned | Thrown; the rest do not run |
| `waterfall` | The outermost listener's return value, as is | Outermost first; each listener's last argument is `next`; `next()` runs the rest of the chain and, at its end, the terminal | Passed along the chain; not calling `next` vetoes the rest | Thrown to the emitter; calling `next` twice, or after the dispatch ended, fails with `WaterfallNext` |
| `bail` (synchronous) | The first result, synchronously | Called synchronously in registration order; listeners elsewhere run as synchronous calls, under the same wait-cycle detection as synchronous service calls | As `serial` | Thrown, the rest do not run; a wait cycle (`SyncWaitCycle`) or a far end that went away fails it; an asynchronous listener fails it with `AsyncListener` |

Rust also has `waterfall_sync`: a synchronous `waterfall`, under the same rules as `bail`.

- **No result**: returning `undefined` / `null` (JavaScript), `None` (Python), `nil` (Go), `None` (Rust), or `false` in any language (Rust's `Some(false)` included). Everything else is a result, `0` and `""` too.
- **`waterfall` returns as is**: no "result or not" normalization, `false` stays `false`. `next` takes no arguments and returns the result of the rest of the chain (JavaScript: a Promise; Python: an awaitable; Go: a blocking call; Rust: a future). The terminal receives the event's arguments; without one, the last `next()` gives no result. With no listeners, `waterfall` returns the terminal's value.
- **Asynchronous listeners**: a JavaScript `async` function, a Python `async def`, a Rust listener registered with `on` cannot be called by `bail` / `waterfall_sync` (`AsyncListener`); a plain function that returns a Promise / coroutine fails the same (the Promise / coroutine is discarded). Go listeners are all synchronous.

### In each language

Each language has the five modes, written the language's own way:

| | Rust (`rutis`) | Node / Bun leaf plugin (`@arcships/rutis`) | Cordis plugin (in the Node runtime) | Python (`rutis`) | Go (`rutis`) | Swift (`Rutis`) | Kotlin（`arcships.rutis`） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Listen | `ctx.events().on(ctx, &key, listener)`; a synchronous listener `on_sync`; with options `on_opt` / `on_sync_opt`; a prefix `on_pattern(ctx, &EventPattern::prefix(p), ..)`; `once` | `ctx.on(name, fn, { prepend, global }?)` → `() => void` | Cordis's own `ctx.on(name, fn, options?)` → `() => boolean`; `ctx.once` | `ctx.on(name, fn, *, prepend=False, global_=False)` → `Callable[[], None]` | `ctx.On(name, func(ctx context.Context, args ...any) (any, error), rutis.Prepend(), rutis.Global())` → `func()` | `ctx.on(name, prepend:, global:) { (args...) in ... }` → `() -> Void` | `ctx.on(name, prepend = false, global = false) { args -> }` → `() -> Unit` |
| Listener | `impl Listener<E>`: `call(ctx, &event, call: Call<'_, E::Value>)`, with `call.mode()`, `call.next()`; an `on_sync` closure gets a `SyncCall` | `(...args[, next]) => value \| Promise` | The same | `fn(*args[, next])`, may be `async def` | `fn(ctx, args...)`; in a waterfall the last argument is a `rutis.Next` (`func(context.Context) (any, error)`) | a closure of any parameters, decoded by their types; in a waterfall the last one is a `Rutis.Next<R>` (`async throws -> R?`) | `suspend (EventArgs) -> Any?`; in a waterfall `args.next` (`suspend () -> Any?`) is the last argument |
| `emit` | `emit(ctx, &key, Arc<E>) -> Result<()>` | `ctx.emit(name, ...args): void` | `ctx.emit([thisArg,] name, ...args)` | `ctx.emit(name, *args) -> None` | `ctx.Emit(ctx, name, args...) error` (refusals only) | `try ctx.emit(name, args...)` (refusals only) | `ctx.emit(name, *args)` (throws only when refused) |
| `parallel` | `parallel(ctx, &key, Arc<E>).await` | `await ctx.parallel(name, ...args)` | `await ctx.parallel([thisArg,] name, ...args)` | `await ctx.parallel(name, *args)` | `ctx.Parallel(ctx, name, args...) error` | `try await ctx.parallel(name, args...)` | `ctx.parallel(name, *args)` (suspends) |
| `serial` | `serial(ctx, &key, Arc<E>).await -> Option<E::Value>` | `await ctx.serial(name, ...args)` | `await ctx.serial([thisArg,] name, ...args)` | `await ctx.serial(name, *args)` | `ctx.Serial(ctx, name, args...) (any, error)` | `try await ctx.serial(name, args..., as: R.self)` | `ctx.serial(name, *args): Any?` (suspends) |
| `waterfall` | `waterfall(ctx, &key, &e, terminal).await` (`()`: no terminal) | `ctx.waterfall(name, ...args)`; with a terminal `ctx.waterfall.with(terminal)(name, ...args)` (every argument is the event's, functions too) | `ctx.waterfall([thisArg,] name, ...args, terminal)` | `await ctx.waterfall(name, *args, terminal=None)` | `ctx.Waterfall(ctx, name, terminal, args...) (any, error)` (`terminal` a `rutis.Terminal`, `func(ctx, args ...any) (any, error)`, or `nil`) | `try await ctx.waterfall(name, args..., as: R.self) { terminal }` | `ctx.waterfall(name, *args, terminal = { args -> })` (suspends) |
| `bail` | `bail_sync(ctx, &key, &e)`; `waterfall_sync(ctx, &key, &e, terminal)` | `ctx.bail(name, ...args)` | `ctx.bail([thisArg,] name, ...args)` | `ctx.bail(name, *args)` | `ctx.Bail(ctx, name, args...) (any, error)` | `try await ctx.bail(name, args..., as: R.self)` (synchronous on the wire) | `ctx.bail(name, *args): Any?` (blocks its thread) |
| Filter | `ctx.events().filter(\|info\| ..)`, then the same six methods | `ctx.filter(d => boolean)` → `{ emit, parallel, serial, waterfall, bail }` | `thisArg[Context.filter] = c => boolean`, `c.rutis` is the descriptor | `ctx.filter(lambda d: ...)` → an object with the five methods | `ctx.Filter(func(rutis.Listener) (bool, error)) *rutis.Emitter` | `ctx.filter { (l: Rutis.Listener) in ... }` → `Rutis.Emitter` | `ctx.filter { d -> Boolean }` → `Emitter` |
| Scope | `ctx.scope()` | the descriptor's `scope` | `ctx.rutis.scope` | the descriptor's `scope` | `ctx.Scope()` | `ctx.scope` | `ctx.scope` |
| Unload signal | a listener is called with the `ctx` that registered it: `ctx.cancelled()` | `ctx.signal` | `ctx.signal` | the listener's task is cancelled | the listener's `ctx` is cancelled | the listener's Task is cancelled | the listener's coroutine is cancelled |
| `parallel` failures | `CordisError::ListenersFailed` | `AggregateError` | `AggregateError` | `rutis.AggregateError` (`errors`) | `*rutis.AggregateError` (`Errors`) | `RutisError` named `AggregateError` (`errors`) | `RutisException` (`name == "AggregateError"`, `errors`) |

In Node, `waterfall` returns a Promise whenever a listener is outside the process, so always `await` it. In Go, pass the `ctx` you received when emitting from a plugin method (it carries the call chain), and `ctx` itself in `Apply`. Rust's emitting methods are on `ctx.events()` and take the emitter's `ctx` first.

The same waterfall listener in the five languages:

```rust
struct Exclaim;
impl Listener<Format> for Exclaim {            // Format: impl Event, Value = String
    fn call<'a>(&'a self, _: &'a Ctx, _: &'a Format, call: Call<'a, String>)
        -> BoxFuture<'a, Result<Option<String>, CordisError>> {
        Box::pin(async move { Ok(call.next().await?.map(|text| format!("{text}!"))) })
    }
}
ctx.events().on(ctx, &EventKey::<Format>::of(), Exclaim)?;
```

```ts
// A Node / Bun leaf plugin; a Cordis plugin writes the same
ctx.on('greeting/format', async (text: string, next: () => Promise<string>) => `${await next()}!`)
```

```python
async def exclaim(text, next):
    return f"{await next()}!"

ctx.on("greeting/format", exclaim)
```

```go
ctx.On("greeting/format", func(ctx context.Context, args ...any) (any, error) {
	inner, err := args[len(args)-1].(rutis.Next)(ctx)
	if err != nil {
		return nil, err
	}
	return fmt.Sprint(inner, "!"), nil
})
```

Each language's guide has a complete example: [TypeScript](typescript-plugin.en.md#events), [Bun](bun-plugin.en.md#events), [Python](python-plugin.en.md#events), [Go](go-plugin.en.md#events), [Cordis](cordis.en.md#events), [Rust](rust-host.en.md#events).

### Scope

A scope is a loader group instance (a copy of an `instanced` group, such as a tenant or a session), or the root. Every plugin and every emission is in one scope: the innermost instance around it, or the root.

> A listener receives the events emitted in its own scope and in every scope inside it.

A listener at the root receives every event; a listener in tenant `t1` does not receive `t2`'s; an event emitted in a session of `t1` reaches the listeners of `t1` and of the root. The host determines the emitter's scope from the emitting row; plugins have no API to emit into another scope: to choose listeners further, use a filter on the descriptor's `scope`. A leaf plugin's `isolate` label (a service scope) has nothing to do with event scopes.

### Filter

An emission can carry a filter function: it is called once for each candidate listener with that listener's **descriptor** and returns whether to deliver.

- It runs **in the emitter's process**, in registration order, before any listener starts; it sees the listeners the scope rule kept, and works the same for listeners anywhere.
- When the filter throws, the whole dispatch fails with that error and no listener starts (in `emit`, it is reported instead).
- Listeners registered with the `global` option are never filtered (the scope rule still applies).

The descriptor (JSON fields, `null` when there is no value; Rust `ListenerInfo`, `None` when there is none; Go `rutis.Listener`, `""` when there is none):

| Field | Meaning |
| --- | --- |
| `name` | The event name (a prefix, for a Rust prefix listener) |
| `prefix` | Whether it is a Rust prefix listener |
| `plugin` | The plugin that registered it: its declared name (`definePlugin({ name })`, `define_plugin(name=)`, the Go plugin's name, a Cordis plugin's name), else its row's id |
| `row` | Its row's id, the name the configuration gives the row (the copies a group's instances make share it); `null` for a plugin loaded by a mount |
| `runtime` | The runtime it runs in; `null` for the host's own Rust plugins |
| `node` | For a listener a node link brought in, the far node's id; `null` otherwise |
| `scope` | Its scope chain, `[{ id, group }]`, outermost first, the root `[]` |
| `global` | Whether it was registered with `global` |

Cordis plugins use Cordis's own way: in `ctx.emit(thisArg, name, ...)` (and the other four), when `thisArg[Context.filter]` is a function it is the filter. A listener in this process is passed its own Cordis `Context`, any other listener `{ rutis: descriptor }`; in the Node runtime every Context has a read-only `ctx.rutis`, so `c => c.rutis.row === 'chat'` works for both.

### `prepend` and `global`

Every language has these two listener options: `prepend` puts the listener before every listener of the name registered so far (the host decides the one registration order everyone sees); `global` exempts it from filters. Rust: `EventOptions::default().prepend(true)` (also `.global(true)`, `.once(true)`) with `on_opt` / `on_sync_opt`; Node / Bun: `ctx.on(name, fn, { prepend: true })` (for a Cordis plugin, Cordis's own options); Python: `ctx.on(name, fn, prepend=True, global_=True)`; Go: `ctx.On(name, fn, rutis.Prepend(), rutis.Global())`.

### Lifecycle

- A listener belongs to the plugin (row) that registered it and is unregistered when the plugin unloads; the returned function unregisters it at once.
- **On unload**: the row's listeners leave the bus first (later events no longer reach them); the ones still running get a cancellation signal — Go the listener's `context`, Python task cancellation, JavaScript the row's `ctx.signal` aborted, Rust `ctx.cancelled()` — and are waited for, at most `RUTIS_SHUTDOWN_TIMEOUT` (10 seconds by default; the host's Rust plugins use the host's shutdown deadline), before the cleanups run. Past it, the runtime writes `rutis: listeners of row <row> still running after <s>s; unloading anyway` on stderr and goes on.
- A call already on its way to a withdrawn listener fails once (`BindingError`, `listener <id> of <name> is withdrawn`, or a transport error); it is never retried.
- **The emitter gives up** (Rust drops the future, Python cancels the task, Go cancels the context): no further listener starts and running ones are cancelled; the emitter gets its language's cancellation. `emit` is not cancelled. JavaScript has no way to cancel a dispatch, and JavaScript listeners have no per-call signal (only `ctx.signal`, on unload).
- Which context a listener runs in: a Rust listener is called with the `ctx` **that registered it**, so what it registers belongs to the listener's plugin; a Go listener's `ctx` carries the emitter's call chain and is cancelled when the emitter gives up or the row unloads: pass it on to the services the listener calls.
- As with Rust's `Ctx::dispose_self`, a listener must not wait for its own row to finish unloading: return from the listener first.

### Disconnection

When a runtime process or a node link goes away, its listeners leave the bus as if their plugins had unloaded: later events no longer go to them (the listeners are gone; nothing is silently dropped). In a dispatch in progress, a call to the side that went away fails once, with the same transport error a service call gets (`BindingError`): `parallel` puts it in its `AggregateError`, `serial` / `waterfall` / `bail` throw it to the emitter, `emit` reports a line. A synchronous wait on it fails the same. There is no call timeout, as for service calls.

### Framework events `rutis/*`

The host publishes framework information with `emit`, one argument (a record) per event. Plugins in every language can listen; any plugin emitting `rutis/*` (in any mode) fails with `ReservedEvent`.

| Event | Argument | When | Scope |
| --- | --- | --- | --- |
| `rutis/service` | `{ name, scope, available, row }` | A service name gets a provider in a scope (`available: true`), the provider is replaced (`true` again, the new `row`), or it is withdrawn with no provider left (`false`) | The service's scope |
| `rutis/row` | `{ row, plugin, scope, state, error }`, `state` one of `pending` / `running` / `failed` / `stopped` | Every state change of a configured row (any language, Rust rows and group rows included); `failed` with `error` | The row's scope |
| `rutis/runtime` | `{ runtime, state, reason }`, `state` one of `running` / `down` | A runtime mounted (after every reconnection too); its session ended or its mount failed (`reason` says why) | The root |

By the scope rule, a listener at the root sees `rutis/row` of every row, one in an instance only the rows in its instance. In Rust the types are `rutis_loader::RowEvent` and `rutis_bridge::events::{ServiceEvent, RuntimeEvent}`. The test tools emit no `rutis/*` events.

`internal/*` is each runtime's own framework machinery (Cordis's `internal/dispatch`, `internal/service` and the like) and never crosses processes: leaf plugins cannot listen to or emit it, and the host refuses to register it (`event <name> is internal to its runtime`). Cordis plugins use it in their process as before; events arriving from elsewhere also go through Cordis's own dispatch, so `internal/dispatch` validators still see them.

### Values

An event's arguments, results, and the results of `next` and the terminal cross on every path as in [passing values](#passing-values): the ten values, references to functions and objects, the 64-level depth limit, between nodes too. A value that cannot be sent fails only that one call (in `parallel` one child of the `AggregateError`, in `emit` a reported line); when the emitter's own arguments cannot be sent, the whole dispatch fails. A reference passed as an argument lives until that call ends.

Rust typed events are named across languages by `Event::NAME` and their arguments are serde-encoded, so an `Event` and its `Value` derive `Serialize` / `Deserialize`. Arity: a tuple struct of two or more fields (`struct Created(String, u32)`) is that many arguments; a unit struct is none; anything else (a struct with named fields, a newtype, a map, a sequence) is one argument. Listeners are found by name: a listener of another Rust type with the same name receives the event too, converted through serde. To send or receive any arguments by name, use `rutis_bridge::events::Args` (`EventKey::<Args>::dynamic(name)`).

### Reported failures

A failure nobody waits for is written in one line where it happens (a runtime on stderr; the host into its error sink, which rutis-host prints with the same text):

| When | The line |
| --- | --- |
| A listener fails in `emit` | `rutis: listener of <name> in row <row> failed: <ErrorName>: <message>` |
| A call that could not be delivered or got no answer (transport, a value, withdrawn), reported by the dispatcher | `rutis: listener of <name> in runtime <runtime> failed: …` or `… in node <peer> failed: …` |
| The filter of an `emit` fails | `rutis: filter of <name> from row <row> failed: …` |
| An `emit` through the host is refused or not answered | `rutis: emit of <name> from row <row> failed: …` (for a plugin a mount loaded `from the mount`, in the filter line too) |
| The host refuses to register a listener (while the row loads, the load fails instead) | `rutis: registration of listener of <name> in row <row> failed: …` |

### Errors

| Name | When | In each language |
| --- | --- | --- |
| `AggregateError` | `parallel` had failures; children in registration order, message `<n> listeners of <name> failed` | JS `AggregateError` (`errors`); Python `rutis.AggregateError` (`errors`); Go `*rutis.AggregateError` (`Errors`); Rust `CordisError::ListenersFailed` |
| `AsyncListener` | `bail` / `waterfall_sync` met an asynchronous listener | JS an `Error` named `AsyncListener`; Python `rutis.AsyncListener`; Go `rutis.ErrAsyncListener`; Rust `CordisError::AsyncListener` |
| `WaterfallNext` | `next` called twice, after the dispatch ended or was cancelled; in Rust, `call.next()` outside a waterfall, or by a synchronous listener in an asynchronous waterfall | JS `WaterfallNext`; Python `rutis.WaterfallNext`; Go `rutis.ErrWaterfallNext`; Rust `CordisError::WaterfallNext` |
| `ReservedEvent` | Emitting `rutis/*`, refused synchronously by the emitting API | JS `ReservedEvent`; Python `rutis.ReservedEvent`; Go `rutis.ErrReservedEvent`; Rust `CordisError::ReservedEvent` |
| `SyncWaitCycle` | A synchronous call (`bail`) would close a cycle of waits | As for service calls: Python `rutis.SyncWaitCycle`; Go `rutis.ErrSyncWaitCycle` |
| `BindingError` | A transport failure, a withdrawn listener, a refused frame | Python `rutis.BindingError`; Go `rutis.ErrBinding`; Rust `CordisError::ListenerWithdrawn` or a transport error |

In Go, check with `errors.Is(err, rutis.ErrWaterfallNext)` and the like; an error of that name from any process matches. An error a listener throws crosses with its name, message and error graph, as any call's error.

**Match a listener's error by its name, not its class.** Where it arrives depends on where the listener runs: from another process it arrives as the language's remote error (TypeScript: an `Error` of the same built-in class or a plain `Error` with that `name`; Python: `rutis.RemoteError`, rutis's own names as their classes; Go: `*rutis.RemoteError`, `errors.As` then `Name`), with its `name`, `message` and `code`; when every listener is in the emitter's process (the fast path), the listener's own error object may arrive. The test tools give a plugin's own emitters the crossed form (in strict mode), so a test catches a match by class; that the fast path keeps the original is not a guarantee.

### Mixing with 0.12 and earlier

The event protocol is rutis 0.13's, with no old path. A runtime or node of 0.12 or earlier connecting to a 0.13 host is refused before anything loads:

```text
incompatible session: the far end (<name> <version>) does not declare events-v2 (the event protocol of rutis 0.13): upgrade it to rutis 0.13 or later
```

A 0.13 runtime meeting an older host exits (status 1): `rutis: refused: incompatible (this host does not declare events-v2 (the event protocol of rutis 0.13): upgrade rutis-host to 0.13 or later); stopping`. Upgrading from 0.12: [migrating to 0.13](../migration-0.13.en.md).

## Lifecycle

The host controls when a plugin runs:

- It starts (`apply`) when all injected services are ready.
- If any injected service is revoked, it stops and cleans up. It starts again when the service returns.
- A configuration change restarts it: cleanup runs, then `apply` runs with the new configuration.
- When a provided service is revoked, plugins that use it stop first, followed by its provider.

Services obtained in `apply` remain valid while the plugin is running, so the plugin does not need to handle a service disappearing midway through its work.

A service name has one provider in rutis: when another plugin (any language, any node) already provides a service of that name, the plugin providing it later fails (to load, or, when it provides it after loading, at that point), and the error names both, for example `service weather is already provided by row forecast: row weather cannot provide it too`. An undeclared service appears only once its plugin runs; plugins depending on it wait for it as usual, and `rutis-host check` reports such a dependency with a warning, `nothing declares <service>; it may be provided at runtime by …`, not as a failure (with `check --strict`, as one: see [Checking a configuration](rutis-host.en.md#checking-a-configuration)). The same for one provided from a thread or goroutine before `apply` returns: the host has handled it before the plugin has loaded, and a clash fails the load.

When a 0.12 runtime is mounted by a host older than 0.12, the host does not take undeclared services, which stay visible in their process only; a plugin providing one is told so on stderr, once per name: `rutis: service <name> is not declared in provides, and this host (older than 0.12) does not take undeclared services; declare it or upgrade rutis-host`. Declare it in `provides`, or upgrade rutis-host.

When the host stops, it unloads every plugin, each cleanup runs once, and then the runtime process exits. When the host goes away without unloading them (it was killed, or crashed), the runtime sees its connection to the host close, unloads every plugin itself, and exits; timers, sockets, threads or goroutines a plugin left behind do not keep it running.

Cleanups have a deadline: when the host stops, the `--shutdown-timeout` of `rutis-host` (10 seconds by default, see [rutis-host](rutis-host.en.md#stopping-and-exit-status)); when the host went away, the runtime uses the same time (`rutis-host` passes it to its runtimes in the `RUTIS_SHUTDOWN_TIMEOUT` environment variable; 10 seconds without it). A cleanup not finished by then, and those after it, are not waited for: the runtime writes a line saying so on stderr and exits with status 1. So work that must happen should not rely on cleanup alone, and a cleanup should not wait without end. In Node and Bun, a cleanup that blocks synchronously (an endless loop) holds the thread, and the deadline cannot interrupt it.

## Passing values

A plugin and the services it uses may run in different processes. Across processes:

| Value | How it is passed |
| --- | --- |
| `null` / `None`, booleans, numbers, strings | Copied |
| Arrays / lists, plain objects / dictionaries with string keys | Recursively copied |
| Python dataclasses | Copied as dictionaries |
| Dates and times, binary data, maps, sets, big integers, decimals, UUIDs | Copied; each language receives its own types, see [the ten values](#the-ten-values) below |
| `Error` / exceptions | Passed as a value: copied as data `{ name, message }` (in TypeScript also `stack`). Thrown: the other side receives an error with the same name and message (in TypeScript a built-in error class keeps its class, any other is an `Error`; in Python a `rutis.RemoteError` whose `name` is the original class name; in Go a `*rutis.RemoteError`). An error thrown in any language may also carry a code and data: in TypeScript a string `code` property and a `data` property, in Python a str `code` attribute and a `data` attribute, in Go the methods `Code() string` and `Data() any`, in Rust [`rutis_bridge::exports::failure`](rust-host.en.md#write-a-hostdispatch-by-hand) (what the `Err(e)` of an [exported Rust service](rust-host.en.md#exported-services-reference) becomes). The receiver reads them as `code` and `data` (Go: `Code`, `Data`; Rust: `Error::code()`, `Error::data()`), and they pass on when it throws the error again. `data` crosses as data (big integers as bigints); data that cannot cross is left out, and the rest of the error still crosses. Other attributes are not passed |
| Functions, Promises / coroutines | Passed by reference: the other side calls or awaits the original |
| Objects with methods, class instances | Passed by reference: the other side receives a proxy that calls the original object |
| `undefined` inside data | Becomes `null` (`None` in Python) |
| Go structs, slices, maps | Copied: struct fields and the items of slices and maps each follow the rules of this section, with field names by their `json` tags; a struct is always data, `rutis.Ref(v)` passes an object by reference. A `map[string]T` is an object, a map whose keys are not strings is a map, and a `map[K]struct{}` is a set |
| Integers beyond ±(2^53−1) | Cross as big integers automatically, see [the ten values](#the-ten-values) |
| Symbols, cyclic references, `NaN` / `Infinity`, other JS typed arrays (such as `Int16Array`), Python `time` with a time zone, Go channels | Cannot cross processes (the call fails) |
| Values nested more than 64 levels deep | Cannot cross processes (the call fails, see below) |

Nesting depth: a value nests at most **64 levels**. Each array / list / tuple, object / dictionary (dataclasses included), map, set, and Go slice, map or struct is a level, whether or not it holds references; an `Error` / exception passed as a value is a level too. A call's argument list is not a level: each argument may nest 64 levels; a result may nest 64 levels. The side that **would send** a deeper value refuses it before sending, failing only that call, with an error naming the limit (`value nested deeper than 64 levels`):

- as an argument: the caller's call fails (in Rust with `Error::Value`) and the far end does not run it;
- as a result: the caller receives the error the callee throws;
- the session goes on, and other calls on it (those running at the same time included) are not affected.

All five runtimes (Rust, Node, Bun, Python, Go) and the test tool's strict mode check this limit when sending. The limit binds the sender: the receiving Rust side leaves a margin for a far end that does not keep to it (an older version, say) and reads frames up to 208 levels deep on the wire, so a value **received** from such a far end may nest deeper than 64 levels (up to about 100 levels of arrays holding references, about 206 of data); that margin is not guaranteed and plugins must not rely on it. When such a far end sends a frame nested too deep for the Rust side to read: if the frame shows which call it belongs to, only that call fails (the far end's call receives an error; a reply to this side's call fails that call), and the references in it are released only when the session ends; if it does not, the session ends, saying why. See [#279](https://github.com/arcships/rutis/issues/279).

Numbers have the limits below. They describe current behaviour and are **not guaranteed** to stay this way (explicitly not guaranteed); a plugin that depends on them must handle them itself:

- In JavaScript (Node, Bun) numbers are IEEE 754 doubles: a JS `number` beyond ±(2^53−1) is already inexact and is sent as it is; use `bigint` to be exact. `-0` becomes `0`; an integral float (Python's `2.0`) arrives in JS as `2` and leaves again as an integer.
- Python keeps `-0.0`.
- NaN and ±Infinity cannot cross.

Values are not copied within one process. Code that mutates an object after passing it may work in a unit test but fail across processes. The test tool's strict mode (enabled by default) applies the rules above to expose this early.

### The ten values

| Value | JS (Node, Bun) | Python | Go | Kotlin | Rust (`rutis-bridge`) | Swift |
| --- | --- | --- | --- | --- | --- | --- |
| Point in time | `Date` | `datetime` with a time zone (received in UTC) | `time.Time` (received in UTC) | `java.time.Instant`, `kotlin.time.Instant` (received as `java.time.Instant`) | `Instant` | `Date` (to the microsecond) |
| Local date and time | String `"2026-10-15T14:30:05"` | `datetime` without a time zone | `rutis.DateTime` | `LocalDateTime` | `DateTime` | `Rutis.DateTime` |
| Date | String `"2026-10-15"` | `date` | `rutis.Date` | `LocalDate` | `Date` | `Rutis.CalendarDate` |
| Time of day | String `"14:30:05"` | `time` without a time zone | `rutis.TimeOfDay` | `LocalTime` | `TimeOfDay` | `Rutis.TimeOfDay` |
| Binary data | `Uint8Array` (`Buffer`, `ArrayBuffer`, `DataView` can be sent too) | `bytes` (`bytearray`, `memoryview` can be sent too) | `[]byte` | `ByteArray` | `Vec<u8>` (`Bytes` in generated code) | `Data` |
| Map | `Map` | `dict` with a key that is not a string (received as a subclass of `dict`) | A map whose keys are not strings (`map[any]any` decoded into `any`) | a `Map` whose keys are not strings | `Vec<(Value, Value)>` (`ValueMap` in generated code) | A `Dictionary` whose keys are not `String` (`[AnyHashable: Any?]` decoded into `Any`) |
| Set | `Set` | `set` (`frozenset` can be sent too) | `map[K]struct{}`, or a slice (a slice decoded into `any`) | `Set` | `Vec<Value>` (`ValueSet` in generated code) | `Set` |
| Big integer | `bigint` | `int` (received as a subclass of `int`) | `*big.Int`, or an integer type that holds it | `BigInteger`, or an integer type that holds it | `BigInt`, or an integer type that holds it | `Rutis.BigInt`, or an integer type that holds it |
| Decimal | String `"12.30"` | `Decimal` | `rutis.Decimal` | `BigDecimal` (its scale kept) | `Decimal` | `Decimal` (38 digits, no trailing zeros; declare `String` for the text) |
| UUID | String (lowercase) | `UUID` | `rutis.UUID` | `java.util.UUID`, `kotlin.uuid.Uuid` | `Uuid` | `UUID` |

- Plugins write their language's native code; rutis does the conversion. A received big integer or map is, in Python, a subclass of `int` or `dict`, used as usual; passed on as it is, it is still a big integer or map.
- JS has no type for local date-times, dates, times of day, decimals or UUIDs: they arrive as plain strings, their content complete, and `===` works as usual. Passed on from JS as they are, such values lose their type (a `date` sent by Python comes back through JS as a `str`). To create one of these five values from nothing in JS, or to pass one on as its type, use the constructors of `@arcships/rutis`: `rutis.datetime('2026-10-15T14:30')`, `rutis.date('2026-10-15')`, `rutis.time('14:30')`, `rutis.decimal('1.10')`, `rutis.uuid('…')`; a plain string is still a string. Go can also decode these five values into a `string`.
- Integers: an integer beyond ±(2^53−1) (absolute value above 9007199254740991; Python `int`, Go `int64` / `uint64`, Rust integers) crosses as a big integer automatically, with nothing special to write; JS receives it as a `bigint`, and within range still as a `number`. A received big integer decodes into a declared integer type that holds it; one that does not hold it fails the call. `bool` is not affected.
- Times: years 0001–9999. A local date and time has no time zone and crosses as it is, with no zone guessed and no conversion to a point in time. A point in time is truncated toward negative infinity to the receiver's precision: milliseconds in JS, microseconds in Python, nanoseconds in Go and Rust; Python also truncates local date-times and times of day to the microsecond.
- A decimal keeps its trailing zeros (`1.10` is not `1.1`) and uses no exponent; NaN and infinities cannot cross. Big integers and decimals have at most 4300 digits.
- Map keys and set elements can only be strings, finite numbers, booleans, big integers, local date-times, dates, times of day, decimals and UUIDs; points in time, binary data, `null`, arrays, objects, maps, sets and references cannot, and the sender refuses them before sending. When two keys become equal after conversion on the receiving side (a JS `Map` with keys `1` and `true` arriving in Python, say), the call fails: an entry would be lost. A JS `Map` with string keys still crosses as a map; a plain Python `dict` with string keys crosses as an object.
- Each value is sent only to a far end that declared it. When the far end does not take it (a runtime older than 0.11, say, integers beyond ±(2^53−1) included), only that call fails, with an error naming the value, and the session and other calls go on. Event arguments and results carry them as calls do, between nodes too.

### Where the test tool differs from a real runtime

The test tools (`@arcships/rutis/testing`, `rutis.testing`, Go's `rutistest`) and the real runtimes are checked against the same expectations file: the same calls on the same plugin (sync, async, callbacks, errors, the values in the table above) must give the same results ([`weather.expected.json`](../../crates/rutis-bridge/src/runtime/testing/weather.expected.json)). In strict mode, these are the only known differences:

| Difference | Why |
| --- | --- |
| A plugin that ends its process (`process.exit`, `os._exit`) ends the test | The test tool runs the plugin in the test's process; the expectations file marks this entry `allowed`, and the test tool does not make that call |
| No restarts: a config change or a withdrawn injected service does not stop and start the plugin | `load` starts it once; the host decides the lifecycle (see above) |
| Sync calls do not block, so there is no `SyncWaitCycle`; no cancellation (`AbortSignal`, coroutine cancellation) | The plugin and the test share one event loop |
| Python: an exception that crosses is a `RemoteError` whose `__cause__` is the original exception | For debugging; a real runtime's `RemoteError` has no `__cause__` |
| Descriptors call the runtime by the language (`node`, `bun`, `python`, `go`; a host uses the names its configuration gives); unloading waits at most `RUTIS_SHUTDOWN_TIMEOUT`, as a runtime, or the tool's own option: TypeScript `host({ deadline })` / `load(…, { deadline, runtime })` in ms, Python `load(…, deadline=, runtime=)` in seconds, Go `rutistest.RuntimeName` and other options | Each tool follows its language's conventions for options |
| TypeScript: only plugins written with `definePlugin` load, not Cordis plugins | The tool has no Cordis plugin model, services or dependency gating |
| Events: every listener is in the test's process (always dispatched locally), with no other process or node, and no `rutis/*` events | The test tool runs the plugins in one process. The five modes, filters, scopes (TypeScript `host()` with `scope`, Python `Bus` and `scope=`, Go `rutistest.InScope`), unload waiting and cancelling, and reporting `emit` failures (`reported`) are as on a real runtime, checked against the same [events expectations file](../../crates/rutis-bridge/src/runtime/testing/events.expected.json) |

The ten values cross by the same rules on both sides, so they are not a difference. With strict mode off (`strict: false`), values skip the table above and other differences can appear.

## Synchronous calls and reentrancy

A method declared `sync` returns synchronously. Across processes, the caller blocks while waiting. During that wait:

- If the callee calls back into the caller, the callback can reach and run in the waiting caller.
- The Python runtime also handles other incoming calls while waiting synchronously. A Python service may therefore be called while it is already handling another synchronous call. **Do not hold locks while calling another service.**
- The Go runtime runs every incoming call on a goroutine of its own, so it is always reentrant: provided Go objects must be safe for concurrent use. The call chain travels in `context.Context`: **pass on the ctx you were given** when calling other services, or a synchronous caller waiting on you may not recognize your callback.
- The Node runtime handles only calls that belong to the current call chain while waiting synchronously; it runs the others once its stack is empty.
- In the Python, Node (and Bun) runtimes, a call run during a synchronous wait is stacked above the waiting one: the call that started first waits for the one that started later.

When runtimes call each other synchronously, every participant may end up waiting for another: two Node runtimes calling each other, or one Node and two Python runtimes in a nested pattern. Before forwarding each synchronous call, the host checks whether it would close such a wait cycle; if it would, the call is not forwarded, its caller gets a `SyncWaitCycle` error, and every other call completes. Do not retry the same call at once (it will most likely close the same cycle again): use an `async` method, try at another moment, or treat it as a failure.

The check covers runtimes that declare the `sync-wait` capability (the Node, Python, Bun and Go runtimes of this repository; the protocol is in §9 of the [multi-language design](../design-multilang-runtimes-2026-10-03.en.md)). Synchronous calls from a runtime that does not declare it (an older SDK) are outside the check and may deadlock as before; a runtime that does not declare `reentrant-sync` is taken as non-reentrant. For calls across runtimes that may cross in both directions, `async` methods are still the first choice.

Do not wait inside a synchronous method for a result that requires the event loop to advance, such as a Promise. This produces `SyncWaitCycle`; make the method `async` instead.

An `async` method runs up to its first `await` before the reply, like a JS async function, so an `async` method that never suspends can be awaited inside a synchronous call chain too. This holds on every supported Python (asyncio's own eager start from 3.12, rutis's on 3.10 and 3.11).

## Cancellation

When the caller abandons an async call (for example, on timeout), the call is cancelled: a Python coroutine is cancelled, a Go method's `context.Context` is cancelled, and a JavaScript method receives an abort when the caller supplied an `AbortSignal` (Rust bindings pass one when calling Cordis methods). Without either mechanism, the callee runs to completion and its result is discarded.

## Versions

Plugins are tagged with the plugin API version they use (`definePlugin` / `define_plugin` / `rutis.Define` adds the tag automatically). If the runtime is older than the plugin requires, loading fails with an explanation of what to upgrade. Depend on the SDK's major version range; it does not need to match the host version.

Plugin API 3 (rutis 0.13) adds `parallel`, `serial`, `waterfall`, `bail` and `filter`, and events become one logical bus; 0.13 runtimes still load API 2 plugins, and an older runtime refuses an API 3 plugin with the existing message. The 0.13 event protocol does not mix with runtimes or nodes of 0.12 and earlier (see [mixing with 0.12 and earlier](#mixing-with-012-and-earlier) above). Plugin API 2 added leaf events; API 1 plugins still load.
