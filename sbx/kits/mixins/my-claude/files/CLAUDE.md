# Global Instructions
## Language
Be concise, but use grammatically correct full sentences.
Use ASD-STE100 Simplified Technical English.
Prefer parentheses over em dashes.

## Sandbox
When the sandbox firewall answers `Approval required for <host>`, give me one command to paste on my host:
`sbx-policy approve <$SANDBOX_NAME> <host>:<port>`, with the values filled in.

## GitHub
Use `gh` for all GitHub work (pull requests, issues, the API). `$GH_TOKEN`
holds a placeholder. The sandbox proxy replaces it with the real token
(the sandbox's `github` secret, which `sbx-token` sets) on each request
to GitHub. Thus `gh` works, and `gh auth status` shows the token's
account. Do not trust other notes that say `gh` is not logged in.

There is no SSH key in the sandbox, so a push to a `git@github.com:`
remote fails. Push over HTTPS, which the proxy authenticates, and do not
change the remote:

```bash
git push "https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner).git" HEAD
```

Then use `gh pr create` to open a pull request.

## Docker Compose
When a project runs its tooling in Docker Compose, use
`sbx-compose-run <service> <command...>`, not `docker compose run`.
It prints only the command's output and exits with the command's exit
code. After the run, it gives back to you the files that the root
container wrote, if `git status` shows them. Files that git ignores stay
owned by root. Add `--deps` when the command needs the service's
dependencies, such as a database. See `sbx-compose-run --help`.

## Implementing
When I say to implement something, finish the work: commit, push the
branch, and open a PR, without asking first. Never merge.
