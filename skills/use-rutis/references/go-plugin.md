# Write a Go Plugin

From creating a project to publishing it, and to a host using it. Needs Go 1.24 or later.

Go plugins follow the same conventions as TypeScript and Python plugins (see the [plugin API](plugin-api.en.md)); what differs is how they are distributed: **a Go plugin is compiled into a binary, and a binary is one runtime process in the host**. A binary holds one or several plugins; a host can run many binaries at once, starting each only when a row uses it.

## 1. Create the project

```bash
rutis-host new weather --lang go
cd weather
go mod tidy
```

The project:

| File | What it is |
| --- | --- |
| `plugin.go` | The plugin (package `weather`, exporting `Plugin`) |
| `plugin_test.go` | Unit tests, no host needed |
| `cmd/weather/main.go` | The binary: `rutis.Serve(weather.Plugin)` |
| `rutis.dev.json` | Configuration of the local runtime and other plugins for testing |
| `go.mod` | The module path (change it to yours); depends on `github.com/arcships/rutis/go/rutis` |
| `.github/workflows/release.yml` | On a `v*` tag: tests, then binaries for every platform on a GitHub release |

## 2. Write the plugin

```go
package weather

import (
	"context"

	"github.com/arcships/rutis/go/rutis"
)

// The configuration: the SDK derives its JSON Schema from this type.
type Config struct {
	City string `json:"city,omitempty" doc:"the city to report on"`
}

// A service it uses: a struct of function fields, named after the methods (Ask -> ask).
type LLM struct {
	Ask func(ctx context.Context, question string) (string, error)
}

// The service it provides: its exported methods are the service's methods.
type Weather struct {
	llm  LLM
	city string
}

func (w *Weather) Today(ctx context.Context) (string, error) {
	answer, err := w.llm.Ask(ctx, "weather in "+w.city) // pass ctx on
	if err != nil {
		return "", err
	}
	return answer + " in " + w.city, nil
}

func (w *Weather) Unit() string { return "celsius" }

var Plugin = rutis.Define(rutis.Plugin[Config]{
	Name:     "weather",
	Inject:   []string{"llm"},                                                       // runs only while all are there
	Provides: rutis.Provides{"weather": rutis.MethodsOf[*Weather](rutis.Sync("Unit"))}, // optional: marks Unit sync; methods are async by default
	Apply: func(ctx *rutis.Ctx, config Config) error {
		var llm LLM
		if err := ctx.Use("llm", &llm); err != nil {
			return err
		}
		ctx.Provide("weather", &Weather{llm: llm, city: config.City})
		ctx.Effect(func(context.Context) error { return nil }) // a cleanup, optional
		return nil
	},
})
```

In short:

| Topic | Rule |
| --- | --- |
| Method names | An exported method's wire name has its first letter lowercased (`Today` → `today`, `URLFor` → `urlFor`, `HTTPServer` → `httpServer`); `rutis.Rename` overrides it |
| Sync or async | `async` by default; `rutis.Sync("Unit")` marks synchronous ones. A sync method blocks a Node caller's event loop: keep methods that do I/O `async` |
| Signatures | `func (T) M([ctx context.Context,] params...) ([result,] [error])` |
| Using services | A struct of function fields may list only the methods it uses; or call by name with `*rutis.Service`: `svc.Call(ctx, "ask", &answer, "q")` |
| `ctx` | `*rutis.Ctx` is a `context.Context` cancelled when the plugin unloads; goroutines the plugin starts use `ctx.Go(...)` or watch `ctx.Done()` |
| Concurrency | Every incoming call runs on its own goroutine: provided objects must be safe for concurrent use; do not hold a lock while calling another service |
| Values | Data (numbers, strings, slices, maps, structs) is copied, struct fields and the items of slices and maps checked one by one (field names follow `json` tags); `time.Time` (an instant, in UTC), `[]byte`, `*big.Int`, maps whose keys are not strings, `map[K]struct{}` (a set) and `rutis.DateTime`, `rutis.Date`, `rutis.TimeOfDay`, `rutis.Decimal`, `rutis.UUID` cross as their own values, see [Passing values](plugin-api.en.md#passing-values); integers beyond ±(2^53−1) (`int64`, `uint64`, ...) cross as big integers by themselves, and a big integer received decodes into the declared integer type, or `*big.Int` into `any`; functions cross by reference; an object crosses by reference only as `rutis.Ref(v)` |
| Errors | A returned `error` crosses with its type name (`*QuotaError` → `QuotaError`; `Name() string` overrides); with `Code() string` and `Data() any` it carries a code and data, which the caller reads as its error's `code` and `data` (`Data` is encoded as JSON); a panic becomes an error named `Panic`. An error received is a `*rutis.RemoteError` with `Name`, `Message`, `Code` and `Data` |

**Always pass ctx on.** The call chain (`path`) lives in `context.Context`: when Node calls your method synchronously and your method calls back into Node synchronously, Node recognizes the chain it is waiting on only if the call carries the ctx you received; with `context.Background()` both sides wait for each other. Under `rutis-host dev`, a call that lost its chain is reported once on stderr.

### Events

Every listener on a host, in any language and any process, is on one event bus ([design](../design-events-2026-10-18.en.md)): where an event is emitted and where its listeners are does not change the result.

```go
off := ctx.On("session/created", func(ctx context.Context, args ...any) (any, error) {
	return nil, nil // nil and false are no result; anything else is one
}, rutis.Prepend()) // options: rutis.Prepend(), rutis.Global()

err := ctx.Emit(callerCtx, "session/created", id)          // returns at once; err only for a refused emission
err = ctx.Parallel(callerCtx, "session/created", id)        // waits for all; *rutis.AggregateError in registration order
value, err := ctx.Serial(callerCtx, "config/resolve", key)   // the first result
value, err = ctx.Bail(callerCtx, "config/resolve", key)      // Serial as a synchronous call
value, err = ctx.Waterfall(callerCtx, "chat/reply", terminal, msg) // terminal may be nil; terminal is a rutis.Terminal, func(ctx context.Context, args ...any) (any, error), called with the event's arguments
value, err = ctx.Filter(func(l rutis.Listener) (bool, error) { return l.Row == "chat", nil }).Serial(callerCtx, "config/resolve", key)
```

A complete example: the plugin answers `greeting/pick` and adds a link to the `greeting/format` waterfall; the service it provides takes the first result with `Serial`, lets other plugins (in any language) rewrite the greeting with `Waterfall`, and notifies with `Emit`:

```go
package greeter

import (
	"context"
	"fmt"

	"github.com/arcships/rutis/go/rutis"
)

type Greeter struct{ ctx *rutis.Ctx }

func (g *Greeter) Hello(ctx context.Context, name, lang string) (string, error) {
	word, err := g.ctx.Serial(ctx, "greeting/pick", lang) // the first result; nil when none
	if err != nil {
		return "", err
	}
	if word == nil {
		word = "Hello"
	}
	text, err := g.ctx.Waterfall(ctx, "greeting/format", func(_ context.Context, args ...any) (any, error) {
		return args[0], nil // the terminal: the innermost end of the chain
	}, fmt.Sprintf("%v, %s", word, name))
	if err != nil {
		return "", err
	}
	if err := g.ctx.Emit(ctx, "greeting/said", name); err != nil { // returns at once
		return "", err
	}
	return text.(string), nil
}

var Plugin = rutis.Define(rutis.Plugin[struct{}]{
	Name: "greeter",
	Apply: func(ctx *rutis.Ctx, _ struct{}) error {
		ctx.On("greeting/pick", func(_ context.Context, args ...any) (any, error) {
			if args[0] == "sv" {
				return "Hej", nil
			}
			return nil, nil // no result: the next listener goes on
		})
		ctx.On("greeting/format", func(ctx context.Context, args ...any) (any, error) {
			next := args[len(args)-1].(rutis.Next) // waterfall: next is the last argument
			inner, err := next(ctx)
			if err != nil {
				return nil, err
			}
			return fmt.Sprintf("%v!", inner), nil
		})
		ctx.Provide("greeter", &Greeter{ctx: ctx})
		return nil
	},
})
```

Python or TypeScript plugins, or Rust code in the host, listening to the same names join the same chain; see [plugin API: events](plugin-api.en.md#events).

| Topic | Rule |
| --- | --- |
| Waterfall | The listener gets `next` (a `rutis.Next`, `func(context.Context) (any, error)`) as its last argument; calling it runs the rest of the chain, not calling it vetoes the rest; a second call fails with `WaterfallNext`. The outermost value is returned as it is |
| Failures | A failing `Emit` listener never reaches the emitter or the other listeners: it is reported where the listener runs (`rutis: listener of <name> in row <row> failed: …` on stderr). `Parallel` runs all and returns an `*rutis.AggregateError` (even for one failure); `Serial`, `Bail` and `Waterfall` stop at the first error and return it |
| Scope | A row hears what is emitted in its scope (`ctx.Scope()`, the loader instances around it) and in every scope inside it, never from beside or above |
| Filter | `Filter(keep)` asks `keep` once per listener, in registration order, before any runs, with its `rutis.Listener` (`Name`, `Prefix`, `Plugin`, `Row`, `Runtime`, `Node`, `Scope`, `Global`); `keep` returns `(bool, error)`: an error it returns (or a panic) fails the dispatch before any listener runs, with that error (`Emit` does not return it but reports a line `rutis: filter of <name> from row <row> failed: …`); listeners registered with `rutis.Global()` skip filters |
| Context | A listener's `ctx` is the emitter's (its call chain), cancelled when the row unloads, and when the emitter of a `Parallel`, `Serial`, `Waterfall` or `Bail` gives up; an `Emit` listener is not cancelled when the emitter gives up. Unloading waits for running listeners, at most `RUTIS_SHUTDOWN_TIMEOUT` |
| Names | `internal/*` is the runtime's own; `rutis/*` (`rutis/service`, `rutis/row`, `rutis/runtime`) can be listened to but not emitted (`ReservedEvent`) |

Pass on the context your caller gave you, as with service calls. `errors.Is(err, rutis.ErrWaterfallNext)` (and `ErrReservedEvent`, `ErrAsyncListener`, `ErrBinding`) matches an error of that name from any process.

## 3. Test

`rutistest` needs no host, but the plugin runs in its real runtime and values cross a real session:

```go
func TestToday(t *testing.T) {
	loaded := rutistest.Load(t, Plugin, Config{City: "Oslo"}, map[string]any{"llm": fakeLLM{}})
	var today string
	if err := loaded.Service("weather").Call(context.Background(), "today", &today); err != nil {
		t.Fatal(err)
	}
}
```

```bash
go test ./...
```

`Provides` is optional: what `ctx.Provide` provides reaches rutis by itself, its methods the value's exported ones, all called as `async`. When present it applies (`Sync` marks synchronous methods, `Rename` renames them), and `rutis-host check` knows before running what the plugin provides.

Events in tests: the test side is the host of the bus. `loaded.Emit`, `Parallel`, `Serial`, `Waterfall`, `Bail` and `Filter` emit from the row's scope; `loaded.On(name, fn)` listens as the host does (the plugin's emissions of that name then go through the test side, as they go through rutis); `loaded.Load(config, rutistest.InScope("t1/s1"))` loads another row in a scope; `loaded.Update(config)` changes a row's config as rutis does (the row loads again, its listeners registered anew, after the others); `loaded.Reported()` is what the runtime reported of failed `Emit` listeners. A test of the `greeter` above:

```go
func TestEvents(t *testing.T) {
	loaded := rutistest.Load(t, Plugin, struct{}{}, nil)
	said := make(chan any, 1)
	loaded.On("greeting/said", func(_ context.Context, args ...any) (any, error) {
		said <- args[0] // the test side listens as the host does
		return nil, nil
	})
	var text string
	if err := loaded.Service("greeter").Call(context.Background(), "hello", &text, "Ada", "sv"); err != nil {
		t.Fatal(err)
	}
	if text != "Hej, Ada!" || <-said != "Ada" {
		t.Fatalf("got %q", text)
	}
	word, err := loaded.Serial(context.Background(), "greeting/pick", "en") // the test emits too
	if err != nil || word != nil {
		t.Fatalf("got %v, %v", word, err)
	}
}
```

`Load` checks what a host would: the plugin uses only the services `Inject` declares; provided services are of the type `Provides` declares (an undeclared service is called as rutis calls it, by its exported methods, all async); cleanups succeed on unload. What works only within one process (passing a struct as an object, relying on shared memory) fails here.

## 4. Run it in a local host

```bash
rutis-host dev
```

`dev` builds `cmd/weather` and runs each of its plugins as the runtime `go-weather`; a change to `.go` files, `go.mod` or `go.sum` rebuilds it and restarts only that runtime, and a failed build keeps the old one running. Other services the plugin needs go in `rutis.dev.json`; they may be Python or TypeScript plugins (with their `runtimes`). `rutis-host check` lists every row and every Go binary with its plugins, versions and plugin API.

## 5. Publish

Push a tag such as `v0.1.0`: the template's workflow runs the tests and `rutis-host check`, builds binaries for Linux and macOS (x64 / arm64) and Windows x64, and publishes them with `SHA256SUMS` on a GitHub release.

Whoever wants your plugin in a binary of their own imports your package: `rutis.Serve(weather.Plugin, other.Plugin)`.

## 6. Used by a host

A host names a Go plugin directory in `rutis.json` and puts binaries there:

```json
{
  "runtimes": { "go": { "dir": "plugins/go" } },
  "rows": [{ "id": "weather", "name": "go:weather", "config": { "city": "Oslo" } }]
}
```

```bash
rutis-host go add example.com/weather/cmd/weather@v0.1.0   # go install, with the machine's Go toolchain
```

Or download the binary for the platform from a release into the directory (on macOS a downloaded binary is quarantined; `rutis-host check` says so). The host finds `go:<plugin>` in all binaries; when two binaries have a plugin of the same name, write `go-<binary name>:<plugin>`. A binary in the directory starts when a row first uses it and stops after 60 s idle (`"start": "eager"` starts all and keeps them running); a replaced binary takes effect when the host restarts. See [rutis-host and rutis.json](rutis-host.en.md); for Rust hosts, [embedding in a Rust application](rust-host.en.md) (`GoResolver`, `GoRuntimes`).

## 7. Run it on another machine

A plugin binary can also run on another machine as a remote runtime, with `language` set to `go`. Two ways, with the same arguments as the Python runtime; see [Connect nodes](nodes.en.md#a-language-runtime-on-another-machine):

```bash
# Listen, and rutis connects (certificate and key in RUTIS_CERT, RUTIS_KEY)
RUTIS_TOKEN=secret RUTIS_CERT=server.pem RUTIS_KEY=server.key \
  ./weather listen:wss://0.0.0.0:7443/rutis --id gpu --peer main .

# Dial out to a rutis access point, reconnecting by fixed rules after a disconnect
RUTIS_TOKEN=secret RUTIS_CA=ca.pem \
  ./weather dial:wss://main.example.com:7443/rutis --id worker-1 --peer main .
```

Dialing out, it reports its state on stderr (`rutis: connected to …` and so on); SIGTERM or Ctrl-C unloads all rows and exits; an incompatible access point makes it exit with status 1. For the rules, see [Runtimes that connect in](nodes.en.md#runtimes-that-connect-in).
