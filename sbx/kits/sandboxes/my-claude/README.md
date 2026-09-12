# my-claude

A sandbox kit for the Claude agent with my custom settings.

## Quick start

```console
sbx run ./sbx/kits/sandboxes/my-claude
```

## Caveat: `mixins:` is forward-compat only right now

As of the current spec v2 release, a sandbox kit's `mixins:` field is accepted at
load time but **not yet applied by the runtime** (a load-time warning fires when
it's used). Until that lands, this kit behaves identically to plain `claude` —
`extends: claude` inherits everything and adds nothing else.

The equivalent that works today is passing the mixin explicitly:

```console
sbx run claude --kit ./sbx/kits/mixins/claude-settings
```

Once runtime `mixins:` composition ships, `sbx run ./sbx/kits/sandboxes/my-claude`
starts applying the claude-settings mixin automatically and this README should drop
this section.
