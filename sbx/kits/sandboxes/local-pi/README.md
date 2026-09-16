# local-pi

A sandbox kit for the [pi](https://pi.dev) coding agent, pointed at an Ollama
server on the host. There is no Anthropic credential and no hosted model, so
nothing leaves the machine.

## On the host, first

Ollama has to be running and reachable from a container. It listens on loopback
only by default, which the sandbox cannot reach, so bind it to every interface:

```console
OLLAMA_HOST=0.0.0.0 ollama serve
ollama pull qwen2.5-coder:7b
ollama pull llama3.1:8b
```

The weights stay on the host. The sandbox holds none of them.

## Quick start

```console
sbx run ./sbx/kits/sandboxes/local-pi
```

## Configuration

Two variables in `spec.yaml` decide what pi talks to:

| Variable           | Default                                | Meaning                                                    |
| ------------------ | -------------------------------------- | ---------------------------------------------------------- |
| `OLLAMA_BASE_URL`  | `http://host.docker.internal:11434/v1` | The server, as addressed from inside the sandbox.           |
| `OLLAMA_MODELS`    | `qwen2.5-coder:7b,llama3.1:8b`         | Model ids. The first one is the startup default.            |

A startup hook renders `~/.pi/agent/models.json` from them on every start, and
seeds `~/.pi/agent/settings.json` with the default model only on the first
start, so `/model` + Ctrl+S keeps working afterwards.

To use another machine's server, set `OLLAMA_BASE_URL` to its address and add
that host to `permissions.network.allow`. Traffic to anything outside the
sandbox goes through the proxy and is denied unless it is listed.

## If the models do not answer

Read `~/.local-pi-kit.log` in the sandbox. The startup hook asks the server for
its model list and records whether it answered.
