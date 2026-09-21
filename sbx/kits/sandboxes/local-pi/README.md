# local-pi

A sandbox kit for the [pi](https://pi.dev) coding agent, pointed at a
self-hosted model server. There are no hosted models configured, and no API
credential.

The server is the Framework running the `ai-server` profile, reached over the
NetBird overlay. Anything that speaks the OpenAI-compatible HTTP interface
works, so the kit names no engine.

## Pre-setup

The kit needs one value it cannot know: where the server is. It is declared as
a required kit argument rather than defaulted, so that the address of a private
machine is never written into a repository that can be published.

Write it once, and `sbx-up` passes it for you:

```console
mkdir -p ~/.config/sbx
printf 'modelHost=%s\n' '<host>' >~/.config/sbx/kit.args
```

Or supply it per run:

```console
sbx run ./sbx/kits/sandboxes/local-pi --kit-arg modelHost=<host>
```

**Use the peer name, not the address.** The overlay resolves peer names inside
a sandbox, and the proxy matches its network policy on the name it was given,
so a name keeps working when the address changes. Read the name from the
overlay client:

```console
netbird status --json | jq -r '.peers.details[].fqdn'
```

Check that the server answers from the host before starting a sandbox. A
failure here is a server or overlay problem; a failure only inside the sandbox
is a policy problem:

```console
curl -fsS http://<host>:8080/v1/models | jq -r '.data[].id'
```

## Quick start

```console
sbx run ./sbx/kits/sandboxes/local-pi --kit-arg modelHost=<host>
```

`sbx` refuses to create the sandbox when the argument is missing, so a forgotten
value is a message rather than a sandbox that talks to nothing.

## Configuration

| Input            | Kind       | Meaning                                                      |
| ---------------- | ---------- | ------------------------------------------------------------ |
| `modelHost`      | kit arg    | The server, as addressed from inside the sandbox. Required.  |
| `modelPort`      | kit arg    | The server's port. Defaults to `8080`.                       |
| `MODEL_BASE_URL` | variable   | Built from the two arguments. Override to point elsewhere.   |
| `MODEL_IDS`      | variable   | Model ids. The first one is the startup default.             |

`modelHost` also becomes the kit's entry in `permissions.network.allow`, so the
sandbox is allowed to reach exactly the server it was told to use, and nothing
else has to be granted by hand.

The variables are named for the role and not for the engine. Every server this
kit has pointed at speaks the same interface, so a name tied to one of them is
wrong as soon as it is replaced, which has happened once already.

A startup hook renders `~/.pi/agent/models.json` from these on every start, and
seeds `~/.pi/agent/settings.json` with the default model only on the first
start, so `/model` + Ctrl+S keeps working afterwards.

### The models

| Model                           | Size    | Active | Good for                                    |
| ------------------------------- | ------- | ------ | ------------------------------------------- |
| `Qwen3.8-Flash-Next-UD-Q4_K_XL` | 111 GB  | 6B     | The default. The strongest that fits.       |
| `Qwen3.6-35B-A3B-UD-Q4_K_XL`    | 22.4 GB | 3B     | The fast one, for scoped work.              |
| `Qwen3.8-27B-UD-Q4_K_XL`        | 17.6 GB | 27B    | Dense. Slower than either of the two above. |

Decode speed follows the active parameters and not the file size, which is why
the largest model is also the faster of the first two. The reasoning is in
`docs/ai-server-decisions.md` in this repository.

**Switching is not free.** The server holds one model in memory and unloads it
when a request names another, at tens of seconds each way. Staying on one model
beats switching per task.

## If the models do not answer

Read `~/.local-pi-kit.log` in the sandbox. The startup hook asks the server for
its model list and records whether it answered, with the three things to check.

The most confusing failure is a `modelHost` that does not match what the agent
actually calls. The kit allows the host it was given and nothing else, so a
mismatch is refused by the proxy and reads exactly like a routing fault.
`sbx policy log` shows the host and the reason.
