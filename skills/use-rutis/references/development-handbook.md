# Rutis Development Handbook

This handbook covers plugin implementation, service calls, resource management, and runtime control. For application structure, see the [Application Development Guide](development-guide.md).

## Quick Start

Add dependencies to a Rust project:

```toml
[dependencies]
rutis = "0.6"
tokio = { version = "1", features = ["rt-multi-thread", "macros", "sync", "time"] }
serde = { version = "1", features = ["derive"] }
```

The following example demonstrates service registration and dependency declaration with one provider and one consumer. Backend provides a service; Indexer declares and uses it.

```rust
use rutis::{BoxFuture, CordisError, Ctx, Effect, Plugin, TypeKey};

struct Backend(String);
struct BackendPlugin(String);

impl Plugin for BackendPlugin {
    fn name(&self) -> &str { "backend" }

    fn apply<'a>(&'a self, ctx: &'a Ctx)
        -> BoxFuture<'a, Result<Effect, CordisError>>
    {
        Box::pin(async move {
            ctx.provide(Backend(self.0.clone()))?;
            Ok(Effect::Done)
        })
    }
}

struct IndexerPlugin {
    dependencies: Vec<TypeKey>,
}

impl Plugin for IndexerPlugin {
    fn name(&self) -> &str { "indexer" }

    fn injects(&self) -> &[TypeKey] { &self.dependencies }

    fn apply<'a>(&'a self, ctx: &'a Ctx)
        -> BoxFuture<'a, Result<Effect, CordisError>>
    {
        Box::pin(async move {
            let backend = ctx.get::<Backend>()
                .ok_or_else(|| CordisError::ServiceNotFound("Backend".into()))?;
            println!("Indexer connected to {}", backend.0);
            Ok(Effect::Done)
        })
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = Ctx::root()?;
    let started = async {
        let backend = root.plugin(BackendPlugin("local".into()));
        (&backend).await?;

        let indexer = root.plugin(IndexerPlugin {
            dependencies: vec![TypeKey::of::<Backend>()],
        });
        (&indexer).await
    }.await;

    let closed = root.shutdown().await;
    started?;
    closed?;
    Ok(())
}
```

Running it prints `Indexer connected to local`. The example initializes the backend before loading Indexer. A real application may register the consumer first; it remains `Pending` until its dependency is ready.

Here, `(&view).await` waits for the plugin to process operations already queued for it. To determine whether a running service is usable, observe whether its provider plugin has entered `Active`; see [Startup and Shutdown](#startup-and-shutdown).

The repository's [complete Indexer example](../crates/rutis/examples/development_workflow.rs) adds a bounded queue, background task, and config update:

```bash
cargo run -p rutis --example development_workflow
```

## Implementing Plugins

### Initialization

Organize `apply` in this order:

1. Read services needed for this load.
2. Create resources and register their cleanup functions.
3. Provide services, register listeners, or create child plugins.
4. Return `Effect` to complete initialization.

Once a plugin is `Active`, its services are available to external consumers. Run continuing work in background tasks and use cleanup functions to stop them.

`name()` is used for logs and diagnostics; `injects()` declares service dependencies; `validate()` validates config owned by the plugin. Plugin implementations must satisfy `Send + Sync + 'static`.

### Choosing a Creation Method

| Creation method | Use when | Reload behavior |
|---|---|---|
| `ctx.plugin(plugin)` | Config is owned by the plugin object | Run `apply` again on the same object |
| `ctx.plugin_with(factory, config)` | Config needs to change at runtime | Create a new plugin object from current config |
| `ctx.plugin_from(build, config)` | Use a simple factory without dependencies | Call closure to create a new plugin object |

Regular plugins declare dependencies in `Plugin::injects()`; factory plugins declare them in `PluginFactory::injects()`. Declarations are fixed at registration and remain fixed for the lifetime of that fiber.

Put resource creation in `apply`. Each reload then uses current dependencies, creates needed resources, and registers fresh cleanup functions.

## Service Keys and Scopes

### Defining Service Keys

Use the same key for registration, dependency declaration, and lookup:

| Service form | Registration | Dependency key | Lookup |
|---|---|---|---|
| Concrete type | `provide(value)` | `TypeKey::of::<T>()` | `get::<T>()` |
| Trait interface | `provide_as::<dyn T>(key, value)` | `key.clone()` | `get_as::<dyn T>(key)` |
| Named service | `provide_as::<T>(key, value)` | `key.clone()` | `get_as::<T>(key)` |

`provide_as` takes `Arc<T>`. For a trait service, the key uses the same trait type; for example, `TypeKey::of::<dyn Store>()` corresponds to `Arc<dyn Store>`.

Distinguish multiple services of the same type with qualifiers:

```rust
use rutis::TypeKey;

struct Backend;

fn primary_backend() -> TypeKey {
    TypeKey::keyed::<Backend>("primary")
}
```

Put such key functions in a public interface module so providers and consumers share them. For names generated at runtime, use `TypeKey::keyed_dynamic`.

### Declaring Dependencies

List required services in `injects()`. The framework waits until each service exists, its provider enters `Active`, and any optional health check passes before calling `apply`.

`get/get_as` finds currently visible services and returns `Option<Arc<T>>`. Automatic reload relationships are established by `injects()`, so declare every required service there.

For services with additional health conditions, register a synchronous predicate with `provide_as_with_check`. When the condition changes, call `ctx.refresh()`; the framework rechecks dependencies and adjusts consumer states accordingly.

### Choosing a Scope

An ordinary type key is for a service shared within root. One active service binding may exist for a given key and scope; duplicate registration returns `ServiceExists`.

`isolate` selects a scope for a particular service key. This snippet creates two independent lookup scopes for the same key:

```rust,ignore
let scope_a = root.isolate(primary_backend(), "a");
let scope_b = root.isolate(primary_backend(), "b");
```

Register providers and consumers in the corresponding contexts to use each binding. Within one root, the same key and label share a scope. Isolate applies to the specified service key; resource ownership follows the original context. For instance-level resource management, see [Instance Subtrees](#instance-subtrees).

## Managing Resources

Plugin authors own the full lifecycle of business resources: initialize through `apply`, and register cleanup through `Effect`. Rutis invokes these implementations according to lifecycle rules. See [Responsibility Boundaries](development-guide.md#responsibility-boundaries).

### Registering Cleanup

The framework registers cleanup for services added with `ctx.provide`, listeners registered through the current `ctx`, and child plugins created with `ctx.plugin`. Register external subscriptions, connections, and tasks through `ctx.effect`.

The following snippet belongs in a plugin's `apply` and demonstrates asynchronous cleanup:

```rust,ignore
ctx.effect(move || {
    Effect::AsyncDisposer(Box::new(move || {
        Box::pin(async move {
            connection.close().await?;
            Ok(())
        })
    }))
})?;
```

The `effect` factory closure runs immediately; its returned cleanup function runs at unload. Register cleanup promptly after acquiring a resource, and release the resource if registration fails. If `apply` fails partway through, the framework runs cleanup already registered.

A `Disposer` handle can release a resource early: call `disposer.dispose().await` and handle its result. Whether the handle is retained or dropped, the owning plugin remains responsible for final cleanup at unload.

### Managing Background Tasks

Background tasks need both a cancellation plan and a way to wait for exit. This shows the basic structure; replace the wait inside the task with the business loop:

```rust,ignore
let token = ctx.cancellation_token();
let stop = token.clone();
let runtime = ctx.handle().clone();

ctx.effect(move || {
    let task = runtime.spawn(async move {
        token.cancelled().await;
    });

    Effect::AsyncDisposer(Box::new(move || {
        Box::pin(async move {
            stop.cancel();
            task.await
                .map_err(|e| CordisError::PluginFailed(Box::new(e)))?;
            Ok(())
        })
    }))
})?;
```

Each `apply` captures the current generation's token and passes it to that generation's tasks. After cancellation, a task completes or cancels its current operation as specified, then exits. The cleanup function waits for actual exit through the `JoinHandle`.

Business loops typically use `tokio::select!` to wait for both input and cancellation. The service interface defines whether queued requests complete, cancel, or are saved. See the complete [IndexerPlugin example](../crates/rutis/examples/development_workflow.rs).

Synchronous computation, blocking operations, and subprocesses also need their own stop mechanism, such as checking cancellation periodically, closing I/O, or terminating and waiting for a process.

### Ordering Cleanup

Cleanup within one plugin runs in reverse registration order. Later-registered resources are released first; the `Effect` returned by `apply` is registered last.

When a consumer must exit before its underlying connection is closed, use this order:

```text
Initialize: create connection and register close → provide service → create dependent child plugin
Cleanup:    close child plugin → remove service and wait for consumers → close connection
```

Acquire objects needed during cleanup in `apply` and capture them. If one cleanup function fails, the framework records the error and continues the remaining cleanup.

After a service is removed from the registry, callers holding an `Arc` can still use it. The implementation should handle calls according to its own running state. For example, the old Indexer in the sample returns an error after its queue closes.

## Using Events

### Event Bus

The event bus manages listener registration, event dispatch, and handler invocation. The sender supplies event data, listeners implement handling logic, and the dispatch API determines execution order, completion conditions, and how results are returned.

Use this mechanism for notifications, request dispatch, or processing shared among multiple plugins. Event types define data and results; the application defines their precise meaning.

### Defining Events and Listeners

Implement `Event` for an event type, specifying the event name and result type; the event and result types implement serde's `Serialize` and `Deserialize` (add `serde = { version = "1", features = ["derive"] }` to the dependencies). Implement handling logic through `Listener`. The following `DocumentIndexed` event carries a document name:

```rust
use std::sync::Arc;
use rutis::{BoxFuture, Call, CordisError, Ctx, Event, EventKey, Listener};

#[derive(serde::Serialize, serde::Deserialize)]
struct DocumentIndexed(String);

impl Event for DocumentIndexed {
    const NAME: &'static str = "app/document-indexed";
    type Value = ();
}

struct Progress;

impl Listener<DocumentIndexed> for Progress {
    fn call<'a>(&'a self, _ctx: &'a Ctx, event: &'a DocumentIndexed, _call: Call<'a, ()>)
        -> BoxFuture<'a, Result<Option<()>, CordisError>>
    {
        Box::pin(async move {
            println!("indexed: {}", event.0);
            Ok(None)
        })
    }
}

fn index(ctx: &Ctx, path: String) -> Result<(), CordisError> {
    let key = EventKey::<DocumentIndexed>::of();
    ctx.events().on(ctx, &key, Progress)?;
    ctx.events().emit(ctx, &key, Arc::new(DocumentIndexed(path)))?;
    Ok(())
}
```

Here, `EventKey::<DocumentIndexed>::of()` names the event `DocumentIndexed::NAME`, `on` registers a listener for that name, and `emit` sends an event under it. Both return `Result`; if an operation fails (for example, the context is already closed), registration or delivery does not occur.

Events match by name. `EventKey::named("…")` (or `EventKey::dynamic` for names generated at runtime) gives the same event type another name; listen to a prefix with `on_pattern` and `EventPattern::prefix("…")`. Different Rust types under the same name hear the same events, converted through serde, so unrelated event types should use different names. Names starting with `rutis/` are reserved for framework events; plugins can only listen to them.

A listener belongs to the `Ctx` passed at registration, and the callback receives that same `Ctx`, not the sender's. Resources the callback registers through it therefore belong to the listening plugin, and `ctx.cancelled()` is that plugin's unload signal. Once a plugin starts unloading, its listeners are no longer called, and the unload waits for their running calls to finish. Runnable code is in the [context ownership example](../crates/rutis/examples/listener_ctx_ownership.rs).

### Choosing a Dispatch Mode

A listener is registered once and every dispatch mode calls it; the sender chooses the mode, and the callback can check it with `call.mode()`.

| API | Execution | Return and error handling |
|---|---|---|
| `emit` | Start each listener's call in registration order in background; same-name events start in send order; calls run concurrently | Returns immediately; each failure goes to ErrorSink as `ListenerFailed` and does not affect other listeners |
| `parallel` | Call listeners concurrently; wait for all | Returns `()` on success; failures aggregate into `ListenersFailed` (also for a single failure), in registration order |
| `serial` | Call one at a time in registration order; stop on a result or error | Return first result; `None` and `Some(false)` count as no result |
| `waterfall` | Listeners call later handlers through `call.next()` and can process their result | Return the outermost listener's result |
| `bail_sync` / `waterfall_sync` | As `serial` / `waterfall`, but synchronously on the caller's thread | Listeners must be registered with `on_sync`; an async listener is an `AsyncListener` error |

Listeners return `Result<Option<E::Value>, CordisError>`. For example, if the event declares `type Value = String`, a serial listener can return a title with `Ok(Some(title))` or pass to the next handler with `Ok(None)`.

In a waterfall, a listener invokes the rest of the chain with `call.next().await` and can process the result; returning directly ends the current flow. In other modes, `next` returns a `WaterfallNext` error. The caller provides the chain's final handler through `terminal` (`()` for none). The event argument stays the same throughout the chain; results flow through return values.

Emit and parallel ignore `Some(value)` returned by listeners; serial uses it to decide when to stop. Choose a dispatch mode based on whether you need to wait for completion, receive a return value, or enforce handler order.

A slow listener does not hold up other calls of the same name, but each emit stays in the backlog until every call it started has finished. `ctx.diagnostics().event_backlogs` lists how many emits per event name have been accepted but not completed and the oldest one's wait duration; use it to identify slow listeners. High-rate data streams can use bounded queues with batching or coalescing to limit backlog; persist data separately if it must be replayed. Processing errors are expressed with `Result`; the caller handles panic in waterfall.

## Instance Subtrees

An instance subtree groups a plugin and its descendants for shared management. Instance service keys limit service scope, event scopes limit where events arrive, and `FiberView::shutdown()` closes the subtree.

Use this structure to manage multiple runtime instances with independent lifetimes. The following workspace example shows how to associate services and events.

### Example: Shared Instance State

The workspace parent plugin creates a service key with its instance ID and passes the key to child plugins. The following snippet belongs in `WorkspacePlugin::apply`; the business types are application-defined:

```rust,ignore
let workspace = ctx.instance();
let state_key = TypeKey::instance::<WorkspaceState>(workspace);

ctx.provide_as::<WorkspaceState>(state_key.clone(), Arc::new(state))?;
ctx.plugin(IndexerPlugin::new(state_key));
Ok(Effect::Done)
```

Indexer uses the provided key in `injects` and `get_as`. This service is visible within the workspace and its child plugins; external management features call through an explicit business interface exposed by the workspace.

Once the parent provides state and creates the child plugin, initialization is complete. The host then waits for Indexer to become ready so the child can obtain the already Active parent service.

### Example: Dispatch Within an Instance

The workspace plugin marks itself as a scope; Progress and Indexer are its child plugins and use their own contexts:

```rust,ignore
// In WorkspacePlugin::apply: this plugin's subtree becomes a scope.
ctx.mark_scope("workspace")?;

let key = EventKey::<DocumentIndexed>::of();

// Register from the Progress child plugin.
progress_ctx.events().on(progress_ctx, &key, Progress)?;

// Emit from the Indexer child plugin.
indexer_ctx.events().emit(indexer_ctx, &key, Arc::new(DocumentIndexed(path)))?;
```

An event sent inside a scope reaches the listeners of that scope and of its enclosing scopes (up to root); sibling workspaces do not hear it, and events sent outside the scope do not reach listeners inside it. Listeners on root hear every event. When the subtree closes, the framework waits for the running calls of its listeners to finish before completing cleanup. Any additional background task created by a callback should be registered using the task-management pattern above.

Isolate service scope is separate from event scopes.

The host coordinates shutdown. If an instance callback needs to close its workspace, it should send a request to the host and return; the host can then wait for shutdown to finish normally, including the current callback.

## Updating Configuration

Plugins that support hot config updates use `PluginFactory`. This factory reuses `BackendPlugin` from Quick Start and validates config during construction:

```rust,ignore
use rutis::PluginFactory;

struct BackendFactory;

impl PluginFactory<String> for BackendFactory {
    fn build(&self, label: &String) -> Result<Box<dyn Plugin>, CordisError> {
        if label.trim().is_empty() {
            return Err(CordisError::Validation {
                issues: vec!["backend label is required".into()],
            });
        }
        Ok(Box::new(BackendPlugin(label.clone())))
    }
}
```

The host registers the plugin with the factory and submits new config later:

```rust,ignore
let backend = root.plugin_with(BackendFactory, String::from("local"));
backend.update(String::from("remote")).await?;
```

An update has two stages:

1. **Preflight.** Run `validate_config`, `build`, and the plugin's `validate`. On failure, return an error and leave current config and instance unchanged.
2. **Reload.** Save new config, clean up the old instance, then construct and load again once dependencies are ready. Consumers reload when services change.

`build` should perform pure object construction; put network connections, task startup, and similar side effects in `apply`. Validation also needed on initial load belongs in `build` or plugin `validate`; `validate_config` is for update preflight.

The real load can still encounter network or resource errors. The host should retain a recovery policy, such as retrying or submitting the last known-good config again. After update, observe the state of the actual business entry point before resuming request handling. To switch to a different dependency set, have the host choose and register the corresponding plugin.

`current_config::<C>()` returns a snapshot of stored config for display and diagnostics. Config updates affect plugin instances in the current process; code upgrades belong to the application release process.

## Startup and Shutdown

### Observing Runtime State

| State | Meaning |
|---|---|
| `Pending` | Waiting for dependencies |
| `Loading` | Initialization in progress |
| `Active` | Initialization succeeded; services are available |
| `Failed` | Initialization failed; error is in the state snapshot |
| `Unloading` | Resource cleanup in progress |
| `Disposed` | Plugin is unloaded |

Use `view.state()` to read a snapshot and `view.watch()` to wait for changes. Startup waits should handle Active, Failed, Disposed, and timeout; see `wait_active` in the [example](../crates/rutis/examples/development_workflow.rs).

`(&view).await` means that previously queued operations for this plugin have been processed. At that point the plugin may still be `Pending` due to missing dependencies; open business entry points only after required plugins are Active. Background-task health is reflected by service state and error reports.

### Choosing Shutdown Scope

To close one plugin and its subtree, call that plugin's `FiberView::shutdown()`. To close the entire application, call `Ctx::shutdown()`. Calling `Ctx::shutdown()` on any child context also shuts down the whole root.

`view.restart()` cleans up and reloads the current plugin. `view.dispose()` unloads it; a regular plugin is done at that point, and future use requires registering a new instance. Root supports restart after ordinary dispose; use shutdown for final application exit.

### Setting a Wait Limit

`dispose_with_timeout` and root `shutdown_with_timeout` provide bounded waits. After timeout, shutdown continues; the caller can record state and wait for the same result again.

To limit waiting for a subtree shutdown, wrap `view.shutdown()` with Tokio timeout:

```rust
use std::sync::Arc;
use std::time::Duration;
use rutis::{CordisError, FiberView};

async fn try_shutdown(view: &FiberView, limit: Duration)
    -> Result<bool, Arc<CordisError>>
{
    match tokio::time::timeout(limit, view.shutdown()).await {
        Ok(result) => {
            result?;
            Ok(true)
        }
        Err(_) => Ok(false),
    }
}
```

`true` means shutdown completed; `false` means this wait timed out. Keep the view and call `view.shutdown().await` again later to obtain the result. Once started, shutdown proceeds independently of the waiter.

When a plugin unloads, the framework waits for its listeners' running calls to finish (they see `ctx.cancelled()`). Manage other work that must be awaited explicitly through task handles and cleanup functions.

## Diagnostics and Verification

### Investigating Problems

`root.diagnostics()` provides snapshots of plugin states, dependencies, and service bindings. Start with these checks:

| Symptom | Check |
|---|---|
| Plugin remains Pending | Missing keys, service scope, provider state, health-check result |
| Service lookup returns None | Registration/lookup type, qualifier, instance ID, and whether provider is Active |
| Old service still used after update | Dependency declarations complete? Did consumer obtain new-generation instance? |
| Plugin enters Failed | Specific reason in `view.state().error` |
| Shutdown waits for a long time | Did initialization finish? Does task respond to cancellation? Are cleanup and listener callbacks complete? |

`diagnostics()` reads current state. For services using health predicates, call `refresh()` after conditions change and inspect the new check result.

### Handling Errors

Lifecycle operations and waiting event APIs return errors directly. Emit listener errors (wrapped as `ListenerFailed`) and cleanup errors during reload go to ErrorSink; default output is stderr, and hosts can use `Ctx::root_with_sink` to connect their own logger.

When releasing an effect early, handle the result of `Disposer::dispose()`. Long-lived plugins may periodically call `take_cleanup_errors()` to retrieve completed historical cleanup failures. The owner of each background task observes and reports its errors.

### Verifying Critical Flows

Verify these scenarios for each plugin:

- When a dependency appears later, the plugin moves from Pending to Active and provides its service correctly.
- After a dependency update, old tasks exit, the new instance uses the new service, and long-lived state is retained as designed.
- If initialization fails midway, already-created resources are cleaned up.
- If update preflight fails, the old instance continues working; if the real load fails, recovery policy can run.
- After one instance subtree shuts down, other independent subtrees keep running.
- If shutdown occurs while a task is running, the task returns its specified request result and eventually completes cleanup.

Coordinate test timing with state, oneshot, Notify, or Barrier, and set timeouts on waits. In the repository, run:

```bash
cargo test -p rutis
cargo run -p rutis --example development_workflow
```

For more details, see [lifecycle contract tests](../crates/rutis/tests/contract.rs), [config update tests](../crates/rutis/tests/config_update.rs), [instance subtree tests](../crates/rutis/tests/instance_subtrees.rs), and [shutdown and deadline notes](core-shutdown-and-disposal-deadline.md).

---

Applies to Rutis 0.3.0. Behavior is based on repository commit `015d48c`. Code marked as a snippet belongs in its stated context; complete programs are in Quick Start and the companion examples.
