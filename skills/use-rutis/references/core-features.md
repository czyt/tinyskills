# Core features

[中文](core-features.md) · [Development handbook](development-handbook.en.md) · [API docs](https://docs.rs/rutis)

What the `rutis` core offers beyond plugins, fibers, services and events, and where its boundaries are. To get started, read the quick start in the [README](../README.md) and the [application design guide](development-guide.en.md) first.

## Config hot update

change config at runtime, reusing the state machine's exactly-once cleanup; affected consumers follow automatically:

```rust
struct MyFactory;
impl PluginFactory<MyConfig> for MyFactory {
    fn build(&self, cfg: &MyConfig) -> Result<Box<dyn Plugin>, CordisError> { /* ... */ }
}

let view = ctx.plugin_with(MyFactory, cfg_v1);
view.update(cfg_v2).await?;   // dry-run failure leaves everything untouched; success unloads + reloads
```

## Events: one listener table, five modes

Events are dispatched by **name** (`EventKey::<E>::of()` is named `E::NAME`; `named` / `dynamic` give another name). Event types derive `Serialize` / `Deserialize`, so listeners of another Rust type with the same name, and listeners in other processes or on other nodes, hear the same event ([unified events design](design-events-2026-10-18.en.md), [protocol spec](design-events-protocol-2026-10-18.en.md) §12.1).

```rust
#[derive(Serialize, Deserialize)]
struct RoomEvent { room: String }
impl Event for RoomEvent { const NAME: &'static str = "room/joined"; type Value = String; }

// Registered once, called by any mode; call.mode() says which, call.next() only in a waterfall
struct Greet;
impl Listener<RoomEvent> for Greet {
    fn call<'a>(&'a self, _ctx: &'a Ctx, e: &'a RoomEvent, _call: Call<'a, String>)
        -> BoxFuture<'a, Result<Option<String>, CordisError>> {
        Box::pin(async move { Ok(Some(format!("hi {}", e.room))) })
    }
}
ctx.events().on(&ctx, &EventKey::of(), Greet)?;
let hi = ctx.events().serial(&ctx, &EventKey::of(), Arc::new(RoomEvent { room: "a".into() })).await?;
```

- `emit` returns at once and starts every listener in registration order without waiting for any; one name's emits start in emit order; a listener's failure goes to the ErrorSink (`ListenerFailed`) and never affects the other listeners.
- `parallel` starts in registration order and waits for all; failures are always `ListenersFailed` (AggregateError), in registration order.
- `serial` / `bail_sync` return the first result (`None` and `Some(false)` are no result); an error stops them. `bail_sync` / `waterfall_sync` meeting an async listener fail with `AsyncListener`.
- `waterfall` / `waterfall_sync` run outer to inner, each listener calling the rest with `call.next()`; not calling it vetoes; the terminal is optional (`()`); the outermost value is returned.
- Synchronous listeners register with `on_sync`; every mode can call them. `EventPattern::prefix("room/")` registers a prefix listener, which gets the actual name. `EventOptions` has `prepend`, `once` and `global`.
- **Scope**: the loader marks group instances with `Ctx::mark_scope(group)`; `Ctx::scope()` is the scope chain from the root. A listener hears events emitted in its own scope and below it, never in a sibling scope.
- **Filter**: `ctx.events().filter(|info: &ListenerInfo| ..)` gives the same emitting methods; the filter sees each non-`global` listener's descriptor (plugin, row, runtime, node, scope) in the emitter's process, before any call.
- **Lifecycle**: a listener is called with the `Ctx` that registered it; once its fiber unloads no new call starts, and the unload waits for running calls (their `ctx.cancelled()` has fired), at most until the host's shutdown deadline.
- `rutis/*` is reserved for framework events: plugins listen to them; emitting one fails with `ReservedEvent`.

## Observing dispatch

`ctx.events().observe_dispatch(&ctx, observer)` calls the observer synchronously before business listeners are selected, even when there are none. An observer sees only dispatches within the subtree of the fiber that registered it and is cleaned up with that fiber; a `DispatchAttempt` carries the event name, the dispatch mode, the emitter and the borrowed event. It records attempts; it cannot veto a dispatch.

## Cleanup tree

`ctx.effect_named("cache watcher", || effect)` names a cleanup entry; `fiber.effects()` returns the fiber's read-only cleanup tree. A composite `Effect::Many` keeps its real nesting, an entry being cleaned up shows as `Draining`, and it leaves the tree once done. Plugin loads, service registrations and event listeners are labelled automatically.

## Intercepting service reads and writes

`ctx.intercept_require_as::<T>(key, hook)` applies only to strict reads that passed the declaration, instance and readiness checks; an explicit `get_as` still locates the service directly. `ctx.intercept_set_as::<T>(key, hook)` handles updates to writable services. `provide_mut_as` returns a `ServiceWriter<T>` bound to the registration's generation, which the provider updates with `writer.set(&ctx, Arc::new(value))`; earlier `Arc<T>` snapshots keep their old value, and a write does not reload consumers. An interceptor can substitute a value of the same type or refuse the operation, so register trusted code only.

## API boundaries

`require/require_as` are strict reads corresponding to Cordis's ordinary plugin service access. They check `injects()` along the fiber ancestry and distinguish undeclared, unavailable, out-of-scope, and inactive reads, retaining the call site. If a read is both out of scope and inactive, the instance boundary takes precedence; registration and instance dispatch define their own error order. `get/get_as` correspond to Cordis's explicit `ctx.get()` locator: they return `Option` without enforcing declarations. A service is normally hidden while its provider is inactive or the reader is unloading, except that the provider's subtree can read its own service during cleanup. Instance keys also have subtree visibility checks. The `Ctx` passed to `on` owns a listener, and the callback is called with that `Ctx`: resources the callback registers belong to the listener's plugin. See the compiling [listener ownership example](../crates/rutis/examples/listener_ctx_ownership.rs).

## Dependency diagnostics

`ctx.diagnostics()` lists live fibers with their identity, state, declared and bound dependencies, and service bindings. `injects[].status` distinguishes missing, out-of-scope instance, provider not ready, being removed, rejected by `check`, and `check` panicked; `TypeKey::describe()` gives the type name, qualifier and instance id. A read uses only registered metadata and the latest gate result: it calls no plugin or `check` and triggers no lifecycle transition. It reads fibers and bindings one by one and is **not an atomic snapshot of the tree**: under concurrent lifecycle changes, the states, dependencies and bindings in one result may come from different moments. A `check` status may lag at the last gate result; after `refresh()`, wait for the affected fibers to settle and read again. Differences from Cordis in dispatch observation, cleanup trees and service interception are covered in the [design draft](design-cordis-observation.en.md).

## Errors and panics

Synchronous and asynchronous `apply` panics become plugin errors; a `check()` panic leaves a dependency unready; a `waterfall` callback panic propagates to its caller. `settle` is a FIFO barrier for one fiber, and Pending can be a stable result. A plugin whose load failed (in construction, `validate` or `apply`) stays Failed and loads again only when its dependencies change (a new provider generation, or one removed and back); repeated notifications of the same dependencies do not retry it. Root `dispose()` remains restartable, while `shutdown()` closes it permanently; dropping a waiting future does not stop cleanup already in progress. `update(config)` reassembles a plugin without replacing process code. An early `Disposer::dispose()` failure returns to its caller without notifying the error sink; `Ctx::take_cleanup_errors()` consumes and releases these retained errors. Unconsumed errors join a terminal unload result or reach the error sink on reload.

## Relation to Cordis

rutis is an idiomatic Rust implementation of the [Cordis](https://github.com/shigma/cordis) paradigm, not a translation: all 96 original specs reviewed line by line, the 58 language-agnostic invariants locked by automated parity tests; every other difference is explicitly declared (decision table + non-port list + audit record). Known deliberate strengthenings: cross-effect cleanup is strictly serial LIFO (cordis runs concurrently), one name's emits start in emit order.
