# VSCode

## Install

[https://code.visualstudio.com/](https://code.visualstudio.com/)

## Setup

* [Install shell command in path](https://code.visualstudio.com/docs/setup/mac) ((⇧⌘P) and type 'shell command')

### Plugins

* [One Dark Pro Theme](https://marketplace.visualstudio.com/items?itemName=zhuangtongfa.Material-theme)
* [Atom Keymap](https://marketplace.visualstudio.com/items?itemName=ms-vscode.atom-keybindings)
* Docker
* GitLens
* markdownlint
* ESLint
* Python
* Pyright

### Settings

```json
{
    "atomKeymap.promptV3Features": true,
    "editor.multiCursorModifier": "ctrlCmd",
    "editor.formatOnPaste": true,
    "editor.rulers": [
        80,
        100,
        120
    ],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "diffEditor.ignoreTrimWhitespace": false,
    "workbench.colorTheme": "One Dark Pro",
    "editor.renderWhitespace": "boundary",
    "editor.renderControlCharacters": true,
    "window.zoomLevel": 1,
    "python.linting.flake8Enabled": true,
    "python.linting.mypyEnabled": true,
    "python.linting.pydocstyleEnabled": true
}
```
