# Design

The `design` and `design-review` skills read this file. Edit it when the project's priorities or design system change.

## Priorities

When two laws of UX conflict, the higher law wins.

1. **<Law>.** <What this law means for this app, in one line.>
2. **<Law>.** <...>
3. **<Law>.** <...>

## Design system

- **Style guide:** <path or URL, or "None yet">
- **Tokens:** <path to the file that defines the base colors and semantic tokens, or "None yet">

### Rules

- **Use semantic tokens in components.** Reference a semantic token for every color. A hex value belongs only in the token file, where the semantic tokens derive from the base colors.
- **Derive new shades from the base colors.** When you need a new shade, apply opacity to an existing base color and add it as a semantic token. This keeps the brand focused and prevents identity sprawl. Add a new base color only when the user approves it.
