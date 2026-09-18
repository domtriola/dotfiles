# VSCode

No profile installs VSCode. It is set up by hand.

## Install

[https://code.visualstudio.com/](https://code.visualstudio.com/)

## Setup

- [Install the shell command in the path](https://code.visualstudio.com/docs/setup/mac): Press ⇧⌘P and type "shell command".

### Plugins

- [One Dark Pro Theme](https://marketplace.visualstudio.com/items?itemName=zhuangtongfa.Material-theme)
- Docker
- GitLens
- markdownlint
- ESLint
- Python
- Pyright

### Settings

```json
{
  "editor.multiCursorModifier": "ctrlCmd",
  "editor.formatOnPaste": true,
  "editor.rulers": [80, 100, 120],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "diffEditor.ignoreTrimWhitespace": false,
  "workbench.colorTheme": "One Dark Pro",
  "editor.renderWhitespace": "boundary",
  "editor.renderControlCharacters": true
}
```
