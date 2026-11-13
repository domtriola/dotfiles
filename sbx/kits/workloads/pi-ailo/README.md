# pi-ailo

A v3 workload for the [pi](https://pi.dev) coding agent, configured to use a
self-hosted model server. It configures no hosted models and no model API
credential.

`pi-ailo.dockerfile` builds on Docker's pi image, `docker.io/sbx/pi`, pinned
by version tag and digest. It takes only the image, not the descriptor of
Docker's pi kit, so this kit does not get that kit's Anthropic credential or
its network allows. Renovate moves the tag and the digest together.

Any server that speaks the OpenAI-compatible HTTP interface works. The kit
names no engine and no model: it is told where the server is, and asks the
server for the rest.

## Pre-setup

A server has to be running and reachable from inside a sandbox, and the kit
needs the one value it cannot work out: where it is.

That value is a required kit argument rather than a default, so that the
address of a private machine is never written into a repository that can be
published. Write it once, and `sbx-up` passes it for you:

```console
mkdir -p ~/.config/sbx
printf 'modelHost=%s\n' '<host>' >~/.config/sbx/kit.args
```

Or supply it per run:

```console
sbx run ./sbx/kits/workloads/pi-ailo --kit-arg modelHost=<host>
```

**Prefer a name to an address.** A name survives the address changing, and the
sandbox proxy matches its network policy on the name it was given, so the
allow list keeps working too.

Check that the server answers from the host before starting a sandbox. A
failure there is a server or network problem; a failure only inside the
sandbox is a policy problem:

```console
curl -fsS http://<host>:8080/v1/models
```

## Quick start

```console
sbx run ./sbx/kits/workloads/pi-ailo --kit-arg modelHost=<host>
```

`sbx` refuses to create the sandbox when the argument is missing, so a
forgotten value is a message rather than a sandbox that talks to nothing.

## Configuration

| Input       | Variable     | Meaning                                                         |
| ----------- | ------------ | --------------------------------------------------------------- |
| `modelHost` | `MODEL_HOST` | The server, as addressed from inside the sandbox. Required.     |
| `modelPort` | `MODEL_PORT` | The server's port. Defaults to `8080`.                          |
| `modelIds`  | `MODEL_IDS`  | Pins the model list. Empty asks the server, which is the usual. |

Each kit arg reaches the container as the variable beside it. The startup
hook builds the base URL, `http://$MODEL_HOST:$MODEL_PORT/v1`, from them.

`modelHost` also becomes the kit's entry in its `network-policy@1` allow
list, so the sandbox may reach exactly the server it was told to use, and
nothing has to be granted by hand.

The variables are named for the role and not for the engine. Every server this
kit has pointed at speaks the same interface, so a name tied to one of them is
wrong as soon as it is replaced, which has happened once already.

A startup hook renders `~/.pi/agent/models.json` on every start, and seeds
`~/.pi/agent/settings.json` with the default model only on the first start, so
`/model` + Ctrl+S keeps working afterwards.

Both hooks run scripts rather than commands inside `pi-ailo.yaml`:

| Script             | When            | What                             |
| ------------------ | --------------- | -------------------------------- |
| `files/install.sh` | once, at create | Points npm at the sandbox proxy. |
| `files/startup.sh` | every start     | Renders the pi configuration.    |

The recipe copies them to `/usr/local/libexec/pi-ailo-kit/`, so they can be
read in a running sandbox as well as in this repository.

The kit also declares:

- `sbx@1`, which every workload for Docker Sandboxes declares: `sbx` starts
  the agent itself, as the image's user.
- `git-identity@1` and a `github` credential, as `my-claude` does (see
  [the sbx README](../../../README.md)). With v2, the `github` secret reached
  every sandbox. With v3, it reaches only a kit that declares it.
- `agent-skills@1` at `~/.agents/skills`, where pi reads skills. The
  `agent-skills` mixin puts its skills there.

## Which models the sandbox sees

**By default, whatever the server says it serves.** The startup hook asks
`/v1/models` and uses the ids it gets back, in the order it gets them. The
first is the startup default, and `/model` switches between the rest.

It also takes each model's context window from that answer and gives it to pi.
Without that, pi rations every conversation to its own default of 128000
tokens whatever the server is configured to serve.

This kit does not own the models, so it names none. A list written into the
kit is a copy of another machine's state, and it is wrong the moment a model is
added or removed there.

**Pin the list to choose the default.** A server's own order is rarely the
order you want, and the first id is what pi starts on:

```console
printf 'modelIds=%s\n' '<best-model>,<second>,<third>' >>~/.config/sbx/kit.args
```

A pinned list is used as given, without asking the server. Ids that the server
does not serve are accepted here and fail when a request names one, so read
the list from the server rather than from memory:

```console
curl -fsS http://<host>:8080/v1/models
```

**Switching may not be free.** A server that loads models on demand holds one
at a time, so naming a different model can unload the one in memory. Where
that is true, staying on one model beats switching per task.

## If the models do not answer

Read `~/.pi-ailo-kit.log` in the sandbox. The startup hook records the server
it used, whether it answered, which ids it found, and the three things that can
be wrong when it did not.

The most confusing failure is a `modelHost` that does not match what the agent
actually calls. The kit allows the host it was given and nothing else, so a
mismatch is refused by the proxy and reads exactly like a routing fault.
`sbx policy log` shows the host and the reason.
