# Write a Python Plugin

This guide covers creating a project, publishing it, and using it from a host. Python 3.10 or later is required. The examples use [uv](https://docs.astral.sh/uv/), but pip and venv work too.

## 1. Create a project

<!-- example: python-en run -->
```bash
uvx rutis-host new weather --lang python
cd weather
uv sync
```

The generated project contains:

| File | Purpose |
| --- | --- |
| `src/weather/__init__.py` | The plugin itself. |
| `tests/test_plugin.py` | Unit tests that do not need a host. |
| `rutis.dev.json` | Local runtime configuration and other plugins used for testing. |
| `pyproject.toml` | Depends on `rutis`; development dependency `rutis-host`; entry point under `rutis.plugins`. |
| `.github/workflows/publish.yml` | Tests and publishes to PyPI when a `v*` tag is pushed. |

## 2. Write the plugin

<!-- example: python-en file=weather/src/weather/__init__.py -->
```python
from rutis import define_plugin


class Weather:
    def __init__(self, llm, city):
        self.llm, self.city = llm, city

    async def today(self):                # async def declares an asynchronous method
        return f"{await self.llm.ask(f'weather in {self.city}')} in {self.city}"


def apply(ctx, config):
    ctx.provide("weather", Weather(ctx.use("llm"), config.get("city", "Oslo")))
    return lambda: None                   # Cleanup may be async; returning nothing is also fine


plugin = define_plugin(
    apply,
    inject=["llm"],                       # Services used: start when all are ready; stop if any is revoked
    config={"type": "object", "properties": {"city": {"type": "string"}}},
)
```

You can also omit `define_plugin` and declare `apply`, `inject`, `provides`, and `Config` directly in the module. `apply` may be an `async def` function.

`weather` needs no declaration: what `ctx.provide` provides reaches rutis by itself, its methods the object's callable attributes not starting with `_`, called as `async`. To mark methods `sync`, or to let `rutis-host check` know before running what the plugin provides, declare `provides`: `provides={"weather": Weather}` reads the class (`async def` methods async, the others sync), or `{"weather": {"unit": "sync"}}`.

`ctx.use("llm")` gets the service. A service provided by a plugin in the same process is the object itself; services from another language or machine are proxies, whose methods return synchronously or produce awaitable results according to their declarations. See [Plugin API](plugin-api.en.md) for capabilities and value passing rules.

## 3. Test

`rutis.testing` does not require a host:

<!-- example: python-en file=weather/tests/test_plugin.py -->
```python
import asyncio
import unittest

from rutis.testing import load
from weather import plugin


class FakeLlm:
    async def ask(self, question):
        return "sunny"


class Weather(unittest.TestCase):
    def test_reports_the_weather_of_the_configured_city(self):
        async def go():
            async with load(plugin, config={"city": "Oslo"}, services={"llm": FakeLlm()}) as t:
                self.assertEqual(await t.service("weather").today(), "sunny in Oslo")

        asyncio.run(go())
```

<!-- example: python-en run -->
```bash
uv run python -m unittest discover -s tests
```

`load` checks the same things as the host: the plugin uses only services declared in `inject`; its provided service has every method declared in `provides` (an undeclared service is called as rutis calls it, by the object's public methods, all async; `t.methods(name)` returns the methods rutis sees); and all cleanup functions run when the `async with` block exits. In strict mode (the default), values follow cross-process rules: data is copied (dataclasses become dictionaries), functions and objects with methods are passed by reference, and `sync` methods cannot return coroutines. Code that works only within one process fails here.

### Events

`ctx.on(name, listener)` listens to an event; `ctx.emit`, `await ctx.parallel`, `await ctx.serial`, `await ctx.waterfall` and `ctx.bail` are the five ways to emit. Listeners register themselves with the host and nothing is declared: whether the emitter is in the same process, in a runtime of another language, in the host or on a linked node, the result is the same. The full rules are in [plugin API: events](plugin-api.en.md#events).

The two plugins below are on one `Bus`: `greeter` takes the first result with `serial`, lets other plugins rewrite the greeting with `waterfall` and notifies with `emit`; `shout` is a link of the waterfall and listens to the notification.

<!-- example: python-en file=weather/tests/test_events.py order=2 -->
```python
import asyncio
import unittest

from rutis import define_plugin
from rutis.testing import Bus, load


def greeter_apply(ctx, config):
    # None or False is "no result": serial asks the next listener
    ctx.on("greeting/pick", lambda lang: "Hej" if lang == "sv" else None)

    class Greeter:
        async def hello(self, name, lang):
            word = await ctx.serial("greeting/pick", lang) or "Hello"
            # terminal: the innermost end of the chain, given the event's arguments
            text = await ctx.waterfall("greeting/format", f"{word}, {name}", terminal=lambda text: text)
            ctx.emit("greeting/said", name)      # returns at once, waits for no listener
            return text

    ctx.provide("greeter", Greeter())


greeter = define_plugin(greeter_apply)
said = []


def shout_apply(ctx, config):
    async def exclaim(text, next):           # a waterfall listener gets next last
        return f"{await next()}!"

    ctx.on("greeting/format", exclaim)
    ctx.on("greeting/said", said.append)


shout = define_plugin(shout_apply)


class Events(unittest.TestCase):
    def test_plugins_hear_each_other(self):
        async def go():
            bus = Bus()                          # plugins on one bus hear each other
            async with load(greeter, bus=bus, row="greeter") as t, load(shout, bus=bus, row="shout"):
                self.assertEqual(await t.service("greeter").hello("Ada", "sv"), "Hej, Ada!")
                self.assertEqual(await t.service("greeter").hello("Bo", "en"), "Hello, Bo!")
                self.assertEqual(said, ["Ada", "Bo"])
                self.assertEqual(await t.serial("greeting/pick", "sv"), "Hej")  # the test can emit too

        asyncio.run(go())
```

- `emit` returns at once; a failing listener reaches neither the emitter nor the other listeners and is reported in one line where it runs (in a test, in `t.reported`). To wait for every listener and get their errors, use `await ctx.parallel(...)`: failures are a `rutis.AggregateError` whose `errors` are in registration order.
- `bail` is a synchronous `serial`: an `async def` listener (or a function returning a coroutine) fails it with `rutis.AsyncListener`.
- `ctx.filter(lambda d: d["row"] == "audit")` returns an object with the five methods that delivers only to the listeners the filter keeps; `ctx.on(name, fn, prepend=True)` goes first, `global_=True` is exempt from filters.
- Scopes: `load(plugin, bus=bus, scope="t1/s1")` loads a plugin into an instance (`Bus(scopes={"t1": "tenant"})` names the groups); a listener receives only the events emitted in its scope and inside it.
- On unload, the tasks of running listeners are cancelled and waited for (at most `RUTIS_SHUTDOWN_TIMEOUT`) before the cleanups run. When the emitter gives up (its task is cancelled), the listeners in progress are cancelled too.

**Across languages**: a TypeScript plugin emits, a Python plugin listens, nothing to change. The host's `rutis.json`:

```json
{
  "runtimes": { "node": { "project": "web" }, "py": { "project": "plugins" } },
  "rows": [
    { "id": "sessions", "name": "sessions" },
    { "id": "audit", "name": "py:audit" }
  ]
}
```

The TypeScript plugin `sessions` in `web/` emits the event, and asks others for a quota with `serial`:

```ts
ctx.provide('sessions', {
  async create(user: string) {
    const quota = (await ctx.serial<number>('session/quota', user)) ?? 1
    const id = crypto.randomUUID()
    await ctx.parallel('session/created', id, user, quota)   // waits for every listener, in any language
    return id
  },
})
```

`plugins/audit.py` answers the quota and records the creation:

```python
import sys

from rutis import define_plugin


def apply(ctx, config):
    ctx.on("session/quota", lambda user: 10 if user == "ada" else None)

    async def created(session_id, user, quota):
        print(f"session {session_id} for {user}, quota {quota}", file=sys.stderr)

    ctx.on("session/created", created)


plugin = define_plugin(apply)
```

Arguments cross processes as in [passing values](plugin-api.en.md#passing-values); an error a Python listener raises is an error of the same name on the TypeScript side (in `parallel`, a child of the `AggregateError`).

## 4. Run in a local host

<!-- example: python-en run until="weather: running" order=99 -->
```bash
uv run rutis-host dev
```

`dev` runs the plugin with the project's `.venv` and reimports it when files change. Add other required services to `rutis.dev.json`, such as a fake `llm` (the row name `py:fake_llm` names the module `fake_llm` in the project's `src/`, shown after it):

<!-- example: python-en file=weather/rutis.dev.json -->
```json
{
  "rows": [
    { "id": "weather", "config": { "city": "Oslo" } },
    { "id": "llm", "name": "py:fake_llm" }
  ]
}
```

<!-- example: python-en file=weather/src/fake_llm.py -->
```python
# src/fake_llm.py
from rutis import define_plugin


class FakeLlm:
    async def ask(self, question):
        return "sunny"


def apply(ctx, config):
    ctx.provide("llm", FakeLlm())


plugin = define_plugin(apply, provides={"llm": FakeLlm})
```

`dev` finds plugin modules in the project's `src/`, so `fake_llm` needs no entry point, and it is not in the built wheel (`pyproject.toml` packages only `src/weather`).

The row with the same ID as the plugin supplies its configuration; the other rows are additional plugins. They may also be TypeScript plugins (in that case, add `"runtimes": { "node": { "project": "." } }` to `rutis.dev.json`). `uv run rutis-host check` lists each row's dependencies, provided services, and configuration schema, and exits with a nonzero status if there is a problem.

Only the plugin module itself is reimported. If another imported module changes, restart `rutis-host dev`.

## 5. Publish

```bash
uv build
uv publish
```

Alternatively, push a tag such as `v0.1.0`. The generated workflow tests, runs `check`, and publishes through PyPI trusted publishing (configure a trusted publisher for the repository on PyPI first).

The entry point in `pyproject.toml` lets the host find the plugin by name:

```toml
[project.entry-points."rutis.plugins"]
weather = "weather"
```

Declare a version range such as `rutis>=0.13,<0.14`. `define_plugin` tags the plugin with its plugin API version. If the host runtime is older, it reports the problem clearly.

## 6. Use from a host

Install the plugin in the Python environment used to run Python plugins (the interpreter named by `py.python` in `rutis.json`), then add a row named `py:<entry-point-name>`:

```bash
uv pip install --python .venv/bin/python weather
```

```json
{ "id": "weather", "name": "py:weather", "config": { "city": "Oslo" } }
```

See [rutis-host and rutis.json](rutis-host.en.md), or [Embed in a Rust application](rust-host.en.md) for a Rust host.
